# frozen_string_literal: true

return unless ENV["COVERAGE"] == "true"

require "simplecov"
require "simplecov-cobertura"

SimpleCov.start do
  enable_coverage :branch

  track_files "lib/**/*.rb"

  add_filter "/spec/"
  add_filter "/vendor/"
  add_filter "/packages/"
  add_filter "/server/"
  add_filter "/landing/"
  add_filter "/demo_app/"
  add_filter "/gemfiles/"

  add_group "Agents", "lib/rails_ai_build/agents"
  add_group "Tools", "lib/rails_ai_build/tools"
  add_group "Models", "lib/rails_ai_build/models"
  add_group "Controllers", "app/controllers"
  add_group "Support", "lib/rails_ai_build/support.rb"

  formatter SimpleCov::Formatter::MultiFormatter.new(
    [
      SimpleCov::Formatter::HTMLFormatter,
      SimpleCov::Formatter::CoberturaFormatter
    ]
  )

  # Report coverage in CI/PR; no hard fail on PRs (review via sticky comment).
  # Enforce no regression on main branch pushes only.
  refuse_coverage_drop if ENV["CI"] == "true" &&
                          ENV["GITHUB_EVENT_NAME"] == "push" &&
                          ENV["GITHUB_REF"] == "refs/heads/main"
end
