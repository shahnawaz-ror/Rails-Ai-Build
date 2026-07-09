# frozen_string_literal: true

module RailsAiBuild
  module Integrations
    class PullRequest
      # Creates a git branch, commits changes, and opens a PR (Team+ feature)
      class << self
        def create(title:, body: nil, branch_prefix: "ai/rails-ai-build")
          Plans.check!(:pr_creation)

          branch = "#{branch_prefix}-#{Time.now.to_i}"
          body ||= "Automated changes by [Rails AI Build](https://github.com/shahnawaz-ror/Rails-Ai-Build)"

          commands = [
            "git checkout -b #{branch}",
            "git add -A",
            "git commit -m #{Shellwords.escape(title)}",
            "git push -u origin #{branch}"
          ]

          results = commands.map { |cmd| run_shell(cmd) }

          {
            branch: branch,
            title: title,
            body: body,
            steps: results,
            pr_url: github_pr_url(branch),
            message: "Branch pushed. Create PR at: #{github_pr_url(branch)}"
          }
        end

        private

        def run_shell(command)
          workspace = RailsAiBuild.configuration.workspace_path
          stdout = `cd #{Shellwords.escape(workspace.to_s)} && #{command} 2>&1`
          { command: command, output: stdout, success: $?.success? }
        end

        def github_pr_url(branch)
          remote = `git remote get-url origin 2>/dev/null`.strip
          return nil if remote.empty?

          repo = remote.gsub(%r{.*github\.com[:/]}, "").gsub(/\.git$/, "")
          "https://github.com/#{repo}/compare/#{branch}?expand=1"
        end
      end
    end
  end
end

require "shellwords"
