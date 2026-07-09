# frozen_string_literal: true

module RailsAiBuild
  module Integrations
    class Git
      class << self
        def status
          in_repo { `git status --porcelain 2>&1` }.strip
        end

        def diff(path: nil)
          cmd = path ? "git diff -- #{Shellwords.escape(path)}" : "git diff"
          in_repo { `#{cmd} 2>&1` }
        end

        def current_branch
          in_repo { `git branch --show-current 2>/dev/null`.strip }
        end

        def create_branch(name)
          in_repo { run!("git checkout -b #{Shellwords.escape(name)}") }
        end

        def commit(message:, paths: nil)
          Plans.check!(:pr_creation)
          in_repo do
            run!("git add #{paths ? Shellwords.escape(paths) : '-A'}")
            run!("git commit -m #{Shellwords.escape(message)}")
          end
        end

        def push(branch: nil)
          cmd = branch ? "git push -u origin #{Shellwords.escape(branch)}" : "git push"
          in_repo { run!(cmd) }
        end

        def log(count: 10)
          in_repo { `git log --oneline -#{count.to_i} 2>&1` }
        end

        def changed_files
          status.lines.map { |l| l.strip.split(/\s+/, 2).last }.compact
        end

        def summary
          {
            branch: current_branch,
            status: status,
            changed_files: changed_files,
            recent_commits: log(count: 5).lines.map(&:chomp)
          }
        end

        private

        def in_repo
          workspace = RailsAiBuild.configuration.workspace_path
          Dir.chdir(workspace) { yield }
        end

        def run!(command)
          output = in_repo { `#{command} 2>&1` }
          success = $?.success?
          { command: command, output: output, success: success }
        end
      end
    end
  end
end

require "shellwords"
