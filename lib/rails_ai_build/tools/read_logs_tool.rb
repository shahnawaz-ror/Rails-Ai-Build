# frozen_string_literal: true

module RailsAiBuild
  module Tools
    class ReadLogsTool < BaseTool
      name 'read_logs'
      description 'Tail lines from a Rails log file (default: log/development.log).'
      parameters type: 'object',
                 properties: {
                   path: { type: 'string', description: 'Relative log path (default: log/development.log)' },
                   lines: { type: 'integer', description: 'Number of lines from end (default 50)' }
                 },
                 required: []

      ALLOWED_LOG_DIRS = %w[log tmp/log].freeze

      def execute(args)
        relative = args['path'].to_s.strip
        relative = 'log/development.log' if relative.empty?
        line_count = (args['lines'] || 50).to_i

        return { error: 'Log path must be under log/ or tmp/log/' } unless allowed_log_path?(relative)

        path = resolve_path(relative)
        return { error: "Log file not found: #{relative}" } unless path.file?

        content = path.read.lines.last(line_count).map(&:chomp)

        {
          path: relative,
          lines: content.size,
          content: content.join("\n")
        }
      end

      private

      def allowed_log_path?(relative)
        normalized = begin
          Workspace::Paths.normalize(workspace, relative)
        rescue SecurityError
          return false
        end
        return false if normalized.include?("..")

        ALLOWED_LOG_DIRS.any? { |dir| normalized == dir || normalized.start_with?("#{dir}/") }
      end
    end
  end
end

