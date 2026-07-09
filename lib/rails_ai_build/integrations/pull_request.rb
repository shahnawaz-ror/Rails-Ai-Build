# frozen_string_literal: true

module RailsAiBuild
  module Integrations
    class PullRequest
      # Creates a git branch, commits changes, and opens a PR (Team+ feature)
      class << self
        def create(title:, body: nil, branch_prefix: "ai/rails-ai-build", provider: :github)
          Plans.check!(:pr_creation)

          branch = "#{branch_prefix}-#{Time.now.to_i}"
          body ||= "Automated changes by [Rails AI Build](https://github.com/shahnawaz-ror/Rails-Ai-Build)"

          Git.create_branch(branch)
          Git.commit(message: title)
          push_result = Git.push(branch: branch)

          pr_url = case provider.to_sym
                   when :gitlab then gitlab_mr_url(branch)
                   else github_pr_url(branch)
                   end

          {
            branch: branch,
            title: title,
            body: body,
            provider: provider,
            push: push_result,
            pr_url: pr_url,
            message: "Branch pushed. Create PR at: #{pr_url}"
          }
        end

        private

        def gitlab_mr_url(branch)
          remote = remote_url
          return nil if remote.empty?

          repo = remote.gsub(%r{.*gitlab\.com[:/]}, "").gsub(/\.git$/, "")
          "https://gitlab.com/#{repo}/-/merge_requests/new?merge_request[source_branch]=#{branch}"
        end

        def github_pr_url(branch)
          remote = remote_url
          return nil if remote.empty?

          repo = remote.gsub(%r{.*github\.com[:/]}, "").gsub(/\.git$/, "")
          "https://github.com/#{repo}/compare/#{branch}?expand=1"
        end

        def remote_url
          workspace = RailsAiBuild.configuration.workspace_path
          Dir.chdir(workspace) { `git remote get-url origin 2>/dev/null`.strip }
        end
      end
    end
  end
end

require "shellwords"
