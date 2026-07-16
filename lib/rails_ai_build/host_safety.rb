# frozen_string_literal: true

require "open3"
require "timeout"

module RailsAiBuild
  # Host Safety Loop — keep the customer app bootable.
  # Prefer generators + deterministic checks; AI only for judgment after rollback.
  module HostSafety
    BOOT_CRITICAL = %r{\A(config/|Gemfile(\.lock)?\z|db/migrate/)}.freeze

    class << self
      def current_session_id
        Thread.current[:rails_ai_build_session_id]
      end

      def current_session_id=(id)
        Thread.current[:rails_ai_build_session_id] = id
      end

      def begin_session!(session_id)
        self.current_session_id = session_id
        Changes::Store.begin_session!(session_id)
        { session_id: session_id, checkpointed: true }
      end

      def end_session!
        self.current_session_id = nil
      end

      # Prevent: syntax gate for Ruby writes
      def validate_write!(path, content)
        return true unless path.to_s.end_with?(".rb")
        return true if content.to_s.strip.empty?

        ok, message = syntax_ok?(content)
        raise ToolError, "Syntax error in #{path}: #{message}" unless ok

        true
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

      # Detect: cheap → expensive ladder after a turn
      def verify_after_turn!(workspace: nil, session_id: nil)
        workspace = Pathname(workspace || RailsAiBuild.configuration.workspace_path)
        session_id ||= current_session_id
        report = { healthy: true, checks: [], rolled_back: false, failure_class: nil, session_id: session_id }

        return report.merge(checks: [{ name: "noop", status: :skipped, message: "Host safety disabled" }]) unless enabled?

        changed = Changes::Store.session_paths(session_id)
        return report.merge(checks: [{ name: "noop", status: :ok, message: "No files changed" }]) if changed.empty?

        ruby_files = changed.select { |p| p.end_with?(".rb") }
        ruby_files.each do |path|
          full = workspace.join(path)
          next unless full.file?

          ok, message = syntax_ok?(full.read)
          report[:checks] << { name: "syntax:#{path}", status: ok ? :ok : :error, message: message }
          next if ok

          report[:healthy] = false
          report[:failure_class] = :syntax
        end

        if report[:healthy] && boot_check_needed?(changed)
          boot = boot_ok?(workspace)
          report[:checks] << boot
          unless boot[:status] == :ok
            report[:healthy] = false
            report[:failure_class] = :boot
          end
        end

        unless report[:healthy]
          rolled = Changes::Store.rollback_session(session_id, workspace: workspace)
          report[:rolled_back] = true
          report[:rollback] = rolled
          Audit.log(action: "host_safety.rollback", metadata: report.slice(:failure_class, :checks, :session_id))
        end

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
    end
  end
end
