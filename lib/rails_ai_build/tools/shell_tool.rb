# frozen_string_literal: true

require "open3"
require "timeout"
require "shellwords"

module RailsAiBuild
  module Tools
    class ShellTool < BaseTool
      name "shell"
      description "Execute an allowlisted shell command in the workspace. Prefer run_generator and run_rails_check. Disabled in production unless config.shell_enabled."
      parameters type: "object",
                 properties: {
                   command: { type: "string", description: "Shell command to execute" },
                   timeout: { type: "integer", description: "Timeout in seconds (default: from config)" }
                 },
                 required: %w[command]

      # Prefix allowlist — first token must match (or be bundle/bin/rails wrappers).
      DEFAULT_ALLOWLIST = %w[
        bundle bin/rails rails rake rspec ruby ruby.exe
        yarn npm pnpm vitest eslint
        git ls cat head tail wc find grep rg
      ].freeze

      BLOCKED_PATTERNS = [
        /\brm\s+-rf\s+(\/|\.\.|\$HOME|~)/i,
        /\bmkfs\b/i,
        /\bdd\s+if=/i,
        %r{>\s*/dev/sd}i,
        /\bcurl\b.*\|\s*(ba)?sh\b/i,
        /\bwget\b.*\|\s*(ba)?sh\b/i,
        /\bchmod\s+777\b/i,
        /\bchown\b/i,
        /\bsudo\b/i,
        /\bnc\b|\bncat\b|\bnetcat\b/i,
        /\beval\b/i,
        /`/,
        /\$\(/,
        /\bpython\b.*-c\b/i,
        /\bperl\b.*-e\b/i
      ].freeze

      def execute(args)
        unless shell_enabled?
          raise SecurityError,
                "shell tool disabled (set config.shell_enabled = true for trusted local agents; prefer run_generator / run_rails_check)"
        end

        command = args["command"].to_s.strip
        raise SecurityError, "Empty command" if command.empty?
        raise SecurityError, "Command blocked for safety" if blocked?(command)
        raise SecurityError, "Command not allowlisted: #{first_token(command)}" unless allowlisted?(command)

        timeout_sec = (args["timeout"] || RailsAiBuild.configuration.shell_timeout).to_i
        timeout_sec = 5 if timeout_sec < 1
        timeout_sec = 300 if timeout_sec > 300

        stdout = +""
        stderr = +""
        pid = nil

        status = Timeout.timeout(timeout_sec) do
          Open3.popen2e(command, chdir: workspace.to_s, pgroup: true) do |_stdin, io, wait_thr|
            pid = wait_thr.pid
            io.each { |line| stdout << line }
            wait_thr.value
          end
        end

        {
          command: command,
          exit_code: status.exitstatus,
          stdout: stdout.truncate_output(50_000),
          stderr: stderr.truncate_output(10_000)
        }
      rescue Timeout::Error
        kill_process_group!(pid)
        { error: "Command timed out after #{timeout_sec}s", command: command }
      end

      private

      def shell_enabled?
        return false if RailsAiBuild.configuration.shell_enabled == false
        return true if RailsAiBuild.configuration.shell_enabled == true

        # Default: on in local/dev/test, off in production-like
        return true unless defined?(Rails)

        !(Rails.env.production? || ENV["RAILS_ENV"].to_s == "production")
      end

      def blocked?(command)
        BLOCKED_PATTERNS.any? { |pattern| command.match?(pattern) }
      end

      def allowlisted?(command)
        token = first_token(command)
        list = Array(RailsAiBuild.configuration.shell_allowlist.presence || DEFAULT_ALLOWLIST).map(&:to_s)
        list.any? { |allowed| token == allowed || token.end_with?("/#{allowed}") }
      end

      def first_token(command)
        Shellwords.shellsplit(command).first.to_s
      rescue ArgumentError
        command.split(/\s+/).first.to_s
      end

      def kill_process_group!(pid)
        return unless pid

        Process.kill("-TERM", pid)
        sleep 0.2
        Process.kill("-KILL", pid)
      rescue Errno::ESRCH, Errno::EPERM
        nil
      end
    end
  end
end

class String
  def truncate_output(max_bytes)
    return self if bytesize <= max_bytes

    byteslice(0, max_bytes) + "\n... (truncated)"
  end
end
