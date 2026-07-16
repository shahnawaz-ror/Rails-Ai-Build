# frozen_string_literal: true

require "securerandom"
require "monitor"

module RailsAiBuild
  module Changes
    PendingChange = Struct.new(
      :id, :path, :old_content, :new_content, :diff, :status, :created_at,
      :session_id, :source, :soft_preview,
      keyword_init: true
    ) do
      def to_h
        {
          id: id,
          path: path,
          diff: diff,
          status: status,
          stats: diff&.dig(:stats),
          created_at: created_at,
          session_id: session_id,
          source: source,
          soft_preview: soft_preview
        }
      end
    end

    class Store
      MAX_CHANGES = 5_000
      MAX_CONTENT_BYTES = 2_000_000

      class << self
        def begin_session!(session_id)
          mutex.synchronize do
            sessions[session_id.to_s] ||= []
            session_id.to_s
          end
        end

        def record(path:, old_content:, new_content:, workspace:, session_id: nil, source: "write_file")
          Plans.check!(:diff_preview) if RailsAiBuild.configuration.diff_preview
          enforce_content_cap!(new_content)

          session_id ||= HostSafety.current_session_id
          begin_session!(session_id) if session_id

          soft = HostSafety.soft_preview_required?(path) && !RailsAiBuild.configuration.diff_preview
          queue = RailsAiBuild.configuration.diff_preview || soft

          diff = Diff.compute(old_content, new_content, path: path)
          change = PendingChange.new(
            id: SecureRandom.uuid,
            path: path,
            old_content: old_content,
            new_content: new_content,
            diff: diff,
            status: :pending,
            created_at: Time.now,
            session_id: session_id,
            source: source,
            soft_preview: soft
          )

          mutex.synchronize do
            memory_store << change
            sessions[session_id.to_s] << change.id if session_id
            evict_changes! if memory_store.size > MAX_CHANGES
          end

          if queue
            {
              status: "pending_approval",
              change_id: change.id,
              path: path,
              diff: diff[:unified],
              stats: diff[:stats],
              soft_preview: soft,
              message: soft ?
                "Boot-critical path queued for approval (Host Safety soft-preview). Apply with Changes::Store.apply('#{change.id}')" :
                "Change queued for review. Apply with RailsAiBuild::Changes::Store.apply('#{change.id}')"
            }
          else
            apply_change(change, workspace)
            change.status = :applied
            result_for(change, "written")
          end
        end

        # Track files already written by rails generate (no second write).
        def track_external(path:, content:, workspace:, session_id: nil, source: "generator", old_content: "")
          session_id ||= HostSafety.current_session_id
          begin_session!(session_id) if session_id
          change = PendingChange.new(
            id: SecureRandom.uuid,
            path: path,
            old_content: old_content.to_s,
            new_content: content.to_s,
            diff: Diff.compute(old_content.to_s, content.to_s, path: path),
            status: :applied,
            created_at: Time.now,
            session_id: session_id,
            source: source,
            soft_preview: false
          )
          mutex.synchronize do
            memory_store << change
            sessions[session_id.to_s] << change.id if session_id
            evict_changes! if memory_store.size > MAX_CHANGES
          end
          change
        end

        def all(status: nil)
          mutex.synchronize do
            list = memory_store.dup
            status ? list.select { |c| c.status == status } : list
          end
        end

        def find(id)
          mutex.synchronize { memory_store.find { |c| c.id == id } }
        end

        def session_paths(session_id)
          return [] if session_id.blank?

          mutex.synchronize do
            ids = sessions[session_id.to_s] || []
            ids.filter_map { |cid| memory_store.find { |c| c.id == cid }&.path }.uniq
          end
        end

        def apply(id, workspace: nil)
          enforce_approval!
          change = find(id)
          raise AgentError, "Change not found: #{id}" unless change
          raise AgentError, "Change already #{change.status}" unless change.status == :pending

          workspace ||= RailsAiBuild.configuration.workspace_path
          HostSafety.validate_write!(change.path, change.new_content)
          apply_change(change, workspace)
          change.status = :applied

          # Gemfile apply → immediate bundle check
          if change.path.to_s.match?(/\AGemfile/) && RailsAiBuild.configuration.host_safety_bundle_check != false
            check = HostSafety::Ladder.bundle_ok?(Pathname(workspace))
            unless check[:status] == :ok
              restore_change!(change, workspace)
              change.status = :rolled_back
              raise AgentError, "bundle check failed after apply: #{check[:message]}"
            end
          end

          Audit.log(action: "change.apply", path: change.path, metadata: { change_id: change.id })
          result_for(change, "applied")
        end

        def reject(id)
          enforce_approval!
          change = find(id)
          raise AgentError, "Change not found: #{id}" unless change
          change.status = :rejected
          Audit.log(action: "change.reject", path: change.path, metadata: { change_id: change.id })
          result_for(change, "rejected")
        end

        def apply_all(workspace: nil)
          enforce_approval!
          pending = all(status: :pending)
          pending.map { |c| apply(c.id, workspace: workspace) }
        end

        def rollback(id, workspace: nil)
          change = find(id)
          raise AgentError, "Change not found: #{id}" unless change

          workspace ||= RailsAiBuild.configuration.workspace_path
          restore_change!(change, workspace)
          change.status = :rolled_back
          Audit.log(action: "change.rollback", path: change.path, metadata: { change_id: change.id })
          result_for(change, "rolled_back")
        end

        def rollback_session(session_id, workspace: nil)
          return { rolled_back: [], session_id: session_id } if session_id.blank?

          workspace ||= RailsAiBuild.configuration.workspace_path
          ids = (sessions[session_id.to_s] || []).dup.reverse
          results = ids.filter_map do |id|
            change = find(id)
            next unless change
            next if change.status == :rolled_back || change.status == :rejected

            # Pending soft-preview never touched disk — only restore applied writes.
            restore_change!(change, workspace) if change.status == :applied
            change.status = :rolled_back
            result_for(change, "rolled_back")
          end
          Audit.log(action: "host_safety.rollback_session", metadata: { session_id: session_id, count: results.size })
          { rolled_back: results, session_id: session_id, count: results.size }
        end

        def clear!
          mutex.synchronize do
            memory_store.clear
            sessions.clear
          end
        end

        private

        def mutex
          @mutex ||= Monitor.new
        end

        def enforce_content_cap!(content)
          return if content.to_s.bytesize <= MAX_CONTENT_BYTES

          raise AgentError, "Change exceeds max size (#{MAX_CONTENT_BYTES} bytes)"
        end

        def evict_changes!
          overflow = memory_store.size - MAX_CHANGES
          return if overflow <= 0

          dropped = memory_store.shift(overflow)
          dropped.each do |change|
            next unless change.session_id

            sessions[change.session_id.to_s]&.delete(change.id)
          end
        end

        def enforce_approval!
          return unless Plans.feature?(:approval_workflow)
          return unless RailsAiBuild.configuration.diff_preview

          Plans.check!(:approval_workflow)
          return unless Rbac.enabled?

          role = Rbac.current_role
          return if %i[admin reviewer].include?(role.to_sym)

          raise SecurityError,
                "Role '#{role}' cannot apply changes under approval_workflow (need admin or reviewer)"
        end

        def memory_store
          @memory_store ||= []
        end

        def sessions
          @sessions ||= Hash.new { |h, k| h[k] = [] }
        end

        def apply_change(change, workspace)
          full = Workspace::Paths.resolve(workspace, change.path, allow_missing: true)
          full.dirname.mkpath
          full.write(change.new_content)
          {
            path: change.path,
            bytes_written: change.new_content.bytesize,
            status: "written"
          }
        end

        def restore_change!(change, workspace)
          full = Workspace::Paths.resolve(workspace, change.path, allow_missing: true)
          if change.old_content.to_s.empty?
            full.delete if full.file?
          else
            full.dirname.mkpath
            full.write(change.old_content)
          end
        end

        def result_for(change, status)
          {
            change_id: change.id,
            path: change.path,
            status: status,
            diff: change.diff&.dig(:unified),
            session_id: change.session_id,
            source: change.source,
            soft_preview: change.soft_preview
          }
        end
      end
    end
  end
end
