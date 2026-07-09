# frozen_string_literal: true

require "open3"
require "timeout"

module RailsAiBuild
  module Tools
    class ShellTool < BaseTool
      name "shell"
      description "Execute a shell command in the workspace directory. Use for running tests, generators, or build commands."
      parameters type: "object",
                 properties: {
                   command: { type: "string", description: "Shell command to execute" },
                   timeout: { type: "integer", description: "Timeout in seconds (default: from config)" }
                 },
                 required: %w[command]

      BLOCKED_PATTERNS = [
        /\brm\s+-rf\s+\/\s*$/,
        /\bmkfs\b/,
        /\bdd\s+if=/,
        /\b>\s*\/dev\/sd/,
        /\bcurl\b.*\|\s*sh\b/,
        /\bwget\b.*\|\s*sh\b/
      ].freeze

      def execute(args)
        command = args["command"].to_s.strip
        raise SecurityError, "Empty command" if command.empty?
        raise SecurityError, "Command blocked for safety" if blocked?(command)

        timeout_sec = (args["timeout"] || RailsAiBuild.configuration.shell_timeout).to_i

        stdout = +""
        stderr = +""

        status = Timeout.timeout(timeout_sec) do
          Open3.popen2e(command, chdir: workspace.to_s) do |_stdin, io, wait_thr|
            io.each do |line|
              (line.start_with?("stderr:") ? stderr : stdout) << line
            end
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
        { error: "Command timed out after #{timeout_sec}s", command: command }
      end

      private

      def blocked?(command)
        BLOCKED_PATTERNS.any? { |pattern| command.match?(pattern) }
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
