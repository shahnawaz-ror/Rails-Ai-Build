# frozen_string_literal: true

module RailsAiBuild
  module Tools
    class ListRakeTasksTool < BaseTool
      name 'list_rake_tasks'
      description 'List available Rake tasks via rails -T or by scanning .rake files.'
      parameters type: 'object',
                 properties: {
                   filter: { type: 'string', description: 'Optional substring filter on task name' },
                   limit: { type: 'integer', description: 'Maximum tasks to return (default 100)' }
                 },
                 required: []

      def execute(args)
        filter = args['filter'].to_s.strip
        limit = (args['limit'] || 100).to_i

        result = run_rails_tasks_list
        tasks = if result[:exit_code].zero? && result[:stdout].present?
                  parse_rails_t_output(result[:stdout])
                else
                  scan_rake_files
                end

        tasks = tasks.select { |t| t[:name].include?(filter) } unless filter.empty?

        {
          source: result[:exit_code].zero? ? 'rails -T' : 'rake file scan',
          count: [tasks.size, limit].min,
          tasks: tasks.first(limit)
        }
      end

      private

      def run_rails_tasks_list
        command = if workspace.join('bin/rails').exist?
                    'bin/rails -T'
                  elsif workspace.join('bin/rake').exist?
                    'bin/rake -T'
                  else
                    'bundle exec rails -T'
                  end

        RailsContext.run_readonly_command(workspace, command)
      end

      def parse_rails_t_output(output)
        output.lines.filter_map do |line|
          next unless line.match?(/^\S/)

          parts = line.strip.split(/\s{2,}/, 2)
          { name: parts[0], description: parts[1].to_s.strip }
        end
      end

      def scan_rake_files
        tasks = []
        rake_dirs = [workspace.join('lib/tasks'), workspace.join('Rakefile')]

        rake_dirs.each do |path|
          files = path.directory? ? path.children.select { |f| f.extname == '.rake' } : [path]
          files.each do |file|
            next unless file.file?

            file.read.scan(/task\s+:?([\w:\[\]]+)/).flatten.each do |name|
              tasks << { name: name, description: "from #{file.relative_path_from(workspace)}" }
            end
          end
        end
        tasks.uniq { |t| t[:name] }
      end
    end
  end
end
