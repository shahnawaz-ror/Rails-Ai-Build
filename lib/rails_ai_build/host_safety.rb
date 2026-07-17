# frozen_string_literal: true

require "open3"
require "timeout"
require "rails_ai_build/host_safety/guards"
require "rails_ai_build/host_safety/ladder"
require "rails_ai_build/host_safety/checkpoint"
require "rails_ai_build/host_safety/shadow"

module RailsAiBuild
  # Host Safety Loop — keep the customer app bootable.
  # prevent → detect → isolate → heal → rollback → report
  module HostSafety
    BOOT_CRITICAL = %r{\A(config/|Gemfile(\.lock)?\z|db/migrate/)}.freeze

    class << self
      def current_session_id
        Thread.current[:rails_ai_build_session_id]
      end

      def current_session_id=(id)
        Thread.current[:rails_ai_build_session_id] = id
      end

      def original_workspace
        Thread.current[:rails_ai_build_original_workspace]
      end

      def original_workspace=(path)
        Thread.current[:rails_ai_build_original_workspace] = path
      end

      # Begin session: checkpoint + optional shadow isolate. Returns effective workspace Pathname.
      def begin_session!(session_id, workspace: nil, on_event: nil)
        workspace = Pathname(workspace || RailsAiBuild.configuration.workspace_path)
        self.current_session_id = session_id
        self.original_workspace = workspace
        Changes::Store.begin_session!(session_id)

        emit(on_event, :status, { phase: "prevent", message: "Host Safety checkpoint…" })
        checkpoint = Checkpoint.create!(session_id, workspace: workspace)

        effective = Shadow.prepare!(session_id, workspace: workspace)
        isolated = Shadow.enabled? && Shadow.meta.present?
        emit(on_event, :status, {
               phase: "isolate",
               message: if isolated
                          "Forked into shadow worktree — host app stays untouched until promote"
                        else
                          "Writing in host workspace (shadow isolation off)"
                        end,
               shadow: isolated,
               workspace: effective.to_s,
               branch: Shadow.meta&.dig(:branch)
             })

        {
          session_id: session_id,
          checkpointed: checkpoint[:ok],
          checkpoint: checkpoint,
          workspace: effective.to_s,
          shadow: isolated,
          branch: Shadow.meta&.dig(:branch)
        }
      end

      def end_session!
        Shadow.cleanup!(keep_meta: false) if Shadow.meta
        self.current_session_id = nil
        self.original_workspace = nil
      end

      def validate_write!(path, content)
        return true unless enabled?

        Guards.validate_write!(path, content)
      end

      def soft_preview_required?(path)
        Guards.soft_preview_required?(path)
      end

      def syntax_ok?(content)
        require "tempfile"
        Tempfile.create(["rab_syntax", ".rb"]) do |f|
          f.write(content)
          f.flush
          out, status = Open3.capture2e("ruby", "-c", f.path)
          return [true, "ok"] if status.success?

          [false, out.to_s.strip]
        end
      rescue StandardError => e
        [false, e.message]
      end

      # Full ladder + rollback / promote / optional heal.
      def verify_after_turn!(workspace: nil, session_id: nil, on_event: nil)
        workspace = Pathname(workspace || Shadow.active_workspace || configuration_workspace)
        session_id ||= current_session_id
        report = base_report(session_id)

        return report.merge(checks: [{ name: "noop", status: :skipped, message: "Host safety disabled" }]) unless enabled?

        changed = Changes::Store.session_paths(session_id)
        if changed.empty?
          Shadow.discard!(session_id) if Shadow.meta
          return report.merge(checks: [{ name: "noop", status: :ok, message: "No files changed" }])
        end

        ladder = Ladder.run!(workspace: workspace, changed: changed, on_event: on_event)
        report.merge!(ladder.slice(:healthy, :checks, :failure_class, :phase))
        Audit.log(action: "host_safety.detect", metadata: report.slice(:failure_class, :session_id, :healthy))

        if report[:healthy]
          finish_healthy!(report, session_id, on_event)
        else
          finish_unhealthy!(report, workspace, session_id, on_event)
        end

        report[:phase] = "report"
        emit(on_event, :host_safety, report)
        report
      end

      def boot_check_needed?(changed)
        changed.any? { |p| p.match?(BOOT_CRITICAL) }
      end

      def boot_ok?(workspace)
        return { name: "boot", status: :ok, message: "Boot check skipped (no bin/rails)" } unless workspace.join("bin/rails").file?
        return { name: "boot", status: :ok, message: "Boot check disabled" } unless boot_check_enabled?

        cmd = "bin/rails runner 'puts :rab_boot_ok'"
        out = +""
        status = Timeout.timeout(45) do
          Open3.popen2e(cmd, chdir: workspace.to_s) do |_stdin, io, wait|
            out << io.read
            wait.value
          end
        end
        if status.success? && out.include?("rab_boot_ok")
          { name: "boot", status: :ok, message: "rails runner OK" }
        else
          { name: "boot", status: :error, message: out.to_s[-2000, 2000] || "boot failed" }
        end
      rescue Timeout::Error
        { name: "boot", status: :error, message: "rails runner timed out" }
      rescue StandardError => e
        { name: "boot", status: :error, message: e.message }
      end

      def enabled?
        RailsAiBuild.configuration.host_safety != false
      end

      def boot_check_enabled?
        RailsAiBuild.configuration.host_safety_boot_check != false
      end

      def status_summary
        {
          enabled: enabled?,
          boot_check: boot_check_enabled?,
          bundle_check: RailsAiBuild.configuration.host_safety_bundle_check != false,
          zeitwerk_check: RailsAiBuild.configuration.host_safety_zeitwerk_check != false,
          soft_preview: RailsAiBuild.configuration.host_safety_soft_preview != false,
          shadow_worktree: Shadow.enabled?,
          smoke_routes: RailsAiBuild.configuration.host_safety_smoke_routes != false,
          fix_after_rollback: RailsAiBuild.configuration.host_safety_fix_after_rollback == true,
          catalog_entries: Generators::Catalog.entries.size
        }
      end

      private

      def configuration_workspace
        RailsAiBuild.configuration.workspace_path
      end

      def base_report(session_id)
        {
          healthy: true,
          checks: [],
          rolled_back: false,
          promoted: false,
          failure_class: nil,
          session_id: session_id,
          phase: "detect",
          actions: []
        }
      end

      def finish_healthy!(report, session_id, on_event)
        if Shadow.meta
          emit(on_event, :status, { phase: "heal", message: "Promoting shadow changes to host…" })
          promoted = Shadow.promote!(session_id)
          report[:promoted] = true
          report[:promote] = promoted
          report[:actions] << { action: :promote, **promoted }
        else
          report[:actions] << { action: :keep }
        end
        Audit.log(action: "host_safety.report", metadata: { healthy: true, session_id: session_id })
      end

      def finish_unhealthy!(report, workspace, session_id, on_event)
        emit(on_event, :status, { phase: "rollback", message: "Host unhealthy — rolling back…" })

        if Shadow.meta
          discarded = Shadow.discard!(session_id)
          report[:rolled_back] = true
          report[:rollback] = { mode: :shadow_discard, **discarded }
          report[:actions] << { action: :shadow_discard, **discarded }
          # Also clear in-memory change tracking so Undo is consistent
          Changes::Store.rollback_session(session_id, workspace: original_workspace || workspace)
        else
          target = original_workspace || workspace
          rolled = Changes::Store.rollback_session(session_id, workspace: target)
          report[:rolled_back] = true
          report[:rollback] = rolled
          report[:actions] << { action: :rollback_session, count: rolled[:count] }
        end

        Audit.log(action: "host_safety.rollback", metadata: report.slice(:failure_class, :checks, :session_id))
        maybe_heal!(report, workspace: original_workspace || workspace, session_id: session_id, on_event: on_event)
      end

      def maybe_heal!(report, workspace:, session_id:, on_event:)
        return unless RailsAiBuild.configuration.host_safety_fix_after_rollback == true
        return if Thread.current[:rails_ai_build_healing]
        return unless report[:rolled_back]

        Thread.current[:rails_ai_build_healing] = true
        emit(on_event, :status, { phase: "heal", message: "Attempting bounded FixSkill after rollback…" })
        max = RailsAiBuild.configuration.host_safety_fix_max_attempts.to_i
        max = 1 if max < 1
        max = 2 if max > 2

        prompt = [
          "Host Safety rolled back session #{session_id} due to #{report[:failure_class]}.",
          "Do NOT reintroduce the same broken change.",
          "Propose a safer minimal fix. Prefer run_generator. Verify carefully.",
          "Failed checks: #{report[:checks].inspect}"
        ].join("\n")

        # Temporarily disable recursive heal
        previous = RailsAiBuild.configuration.host_safety_fix_after_rollback
        RailsAiBuild.configuration.host_safety_fix_after_rollback = false
        result = Ai::Driver.run(prompt, skill: :fix, workspace: workspace)
        report[:actions] << { action: :fix_skill, attempts: max, content_preview: result.content.to_s[0, 200] }
        report[:healed] = true
      rescue StandardError => e
        report[:actions] << { action: :fix_skill_failed, error: e.message }
      ensure
        RailsAiBuild.configuration.host_safety_fix_after_rollback = previous if defined?(previous)
        Thread.current[:rails_ai_build_healing] = false
      end

      def emit(on_event, event, data)
        on_event&.call(event, data)
      end
    end
  end
end
