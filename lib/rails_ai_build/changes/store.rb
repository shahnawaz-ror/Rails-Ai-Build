# frozen_string_literal: true

module RailsAiBuild
  module Changes
    PendingChange = Struct.new(
      :id, :path, :old_content, :new_content, :diff, :status, :created_at,
      keyword_init: true
    ) do
      def to_h
        {
          id: id,
          path: path,
          diff: diff,
          status: status,
          stats: diff&.dig(:stats),
          created_at: created_at
        }
      end
    end

    class Store
      class << self
        def record(path:, old_content:, new_content:, workspace:)
          Plans.check!(:diff_preview) if RailsAiBuild.configuration.diff_preview

          diff = Diff.compute(old_content, new_content, path: path)
          change = PendingChange.new(
            id: SecureRandom.uuid,
            path: path,
            old_content: old_content,
            new_content: new_content,
            diff: diff,
            status: :pending,
            created_at: Time.now
          )

          if RailsAiBuild.configuration.diff_preview
            memory_store << change
            {
              status: "pending_approval",
              change_id: change.id,
              path: path,
              diff: diff[:unified],
              stats: diff[:stats],
              message: "Change queued for review. Apply with RailsAiBuild::Changes::Store.apply('#{change.id}')"
            }
          else
            apply_change(change, workspace)
          end
        end

        def all(status: nil)
          list = memory_store
          status ? list.select { |c| c.status == status } : list
        end

        def find(id)
          memory_store.find { |c| c.id == id }
        end

        def apply(id, workspace: nil)
          change = find(id)
          raise AgentError, "Change not found: #{id}" unless change
          raise AgentError, "Change already #{change.status}" unless change.status == :pending

          workspace ||= RailsAiBuild.configuration.workspace_path
          apply_change(change, workspace)
          change.status = :applied
          result_for(change, "applied")
        end

        def reject(id)
          change = find(id)
          raise AgentError, "Change not found: #{id}" unless change
          change.status = :rejected
          result_for(change, "rejected")
        end

        def apply_all(workspace: nil)
          pending = all(status: :pending)
          pending.map { |c| apply(c.id, workspace: workspace) }
        end

        def clear!
          memory_store.clear
        end

        private

        def memory_store
          @memory_store ||= []
        end

        def apply_change(change, workspace)
          full = workspace.join(change.path.to_s.sub(%r{\A/}, ""))
          full.dirname.mkpath
          full.write(change.new_content)
          {
            path: change.path,
            bytes_written: change.new_content.bytesize,
            status: "written"
          }
        end

        def result_for(change, status)
          {
            change_id: change.id,
            path: change.path,
            status: status,
            diff: change.diff&.dig(:unified)
          }
        end
      end
    end
  end
end

require "securerandom"
