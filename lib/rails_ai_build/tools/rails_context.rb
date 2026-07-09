# frozen_string_literal: true

module RailsAiBuild
  module Tools
    # Shared helpers for Rails introspection tools (works with or without a loaded app).
    module RailsContext
      module_function

      def rails_loaded?
        defined?(Rails) && Rails.respond_to?(:application) && !Rails.application.nil?
      end

      def infer_rails_version(workspace)
        lock = workspace.join('Gemfile.lock')
        if lock.exist?
          lock.read.scan(/^\s+rails \((\d+\.\d+(?:\.\d+)?)\)/).flatten.last&.then { |v| v }
        end || gemfile_rails_version(workspace) || (rails_loaded? ? Rails.version : nil)
      end

      def gemfile_rails_version(workspace)
        gemfile = workspace.join('Gemfile')
        return nil unless gemfile.exist?

        content = gemfile.read
        return ::Regexp.last_match(1) if content =~ /gem\s+['"]rails['"],\s*['"]~>\s*(\d+\.\d+)/
        return ::Regexp.last_match(1) if content =~ /gem\s+['"]rails['"],\s*['"](\d+\.\d+(?:\.\d+)?)/

        nil
      end

      def infer_ruby_version(workspace)
        version_file = workspace.join('.ruby-version')
        return version_file.read.strip if version_file.exist?

        RUBY_VERSION
      end

      def guides_base_url(rails_version)
        major_minor = rails_version.to_s.split('.').first(2).join('.')
        case major_minor
        when '8.1', '8.0' then 'https://guides.rubyonrails.org/v8.0'
        when '7.2' then 'https://guides.rubyonrails.org/v7.2'
        when '7.1' then 'https://guides.rubyonrails.org/v7.1'
        when '7.0' then 'https://guides.rubyonrails.org/v7.0'
        else 'https://guides.rubyonrails.org'
        end
      end

      def run_readonly_command(workspace, command, timeout: 15)
        require 'open3'
        require 'timeout'

        stdout = +''
        stderr = +''

        status = Timeout.timeout(timeout) do
          Open3.popen2e(command, chdir: workspace.to_s) do |_stdin, io, wait_thr|
            io.each { |line| stdout << line }
            wait_thr.value
          end
        end

        { exit_code: status.exitstatus, stdout: stdout, stderr: stderr }
      rescue Timeout::Error
        { exit_code: -1, stdout: stdout, stderr: "Timed out after #{timeout}s" }
      end
    end
  end
end
