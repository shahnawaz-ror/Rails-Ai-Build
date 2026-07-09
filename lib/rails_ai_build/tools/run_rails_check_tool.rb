# frozen_string_literal: true

module RailsAiBuild
  module Tools
    class RunRailsCheckTool < BaseTool
      name 'run_rails_check'
      description 'Run Rails health checks: zeitwerk:check, rspec/minitest, rubocop.'
      parameters type: 'object',
                 properties: {
                   checks: {
                     type: 'array',
                     items: { type: 'string', enum: %w[zeitwerk test rubocop] },
                     description: 'Checks to run (default: zeitwerk, test)'
                   },
                   test_path: { type: 'string', description: 'Optional spec/test path for test check' }
                 },
                 required: []

      DEFAULT_CHECKS = %w[zeitwerk test].freeze

      def execute(args)
        checks = Array(args['checks']).presence || DEFAULT_CHECKS
        test_path = args['test_path'].to_s.strip
        results = {}

        checks.each do |check|
          results[check] = run_check(check, test_path: test_path)
        end

        {
          passed: results.values.all? { |r| r[:passed] },
          checks: results
        }
      end

      private

      def run_check(name, test_path:)
        command = command_for(name, test_path: test_path)
        return { passed: true, skipped: true, reason: 'command not available' } unless command

        result = RailsContext.run_readonly_command(workspace, command, timeout: 120)
        passed = result[:exit_code].zero?
        {
          passed: passed,
          exit_code: result[:exit_code],
          command: command,
          stdout: result[:stdout].to_s.truncate_output(8000),
          stderr: result[:stderr].to_s.truncate_output(2000)
        }
      end

      def command_for(name, test_path:)
        case name
        when 'zeitwerk'
          rails_cmd('zeitwerk:check')
        when 'test'
          test_cmd(test_path)
        when 'rubocop'
          'bundle exec rubocop --force-exclusion -f simple'
        end
      end

      def rails_cmd(task)
        return "bin/rails #{task}" if workspace.join('bin/rails').exist?

        "bundle exec rails #{task}"
      end

      def test_cmd(path)
        if workspace.join('spec').directory?
          path.present? ? "bundle exec rspec #{Shellwords.escape(path)}" : 'bundle exec rspec --fail-fast'
        elsif workspace.join('test').directory?
          path.present? ? "bin/rails test #{Shellwords.escape(path)}" : 'bin/rails test'
        end
      end
    end
  end
end

require 'shellwords'
