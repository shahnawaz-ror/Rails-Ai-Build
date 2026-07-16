# frozen_string_literal: true

require_relative "lib/rails_ai_build/version"

Gem::Specification.new do |spec|
  spec.name = "rails_ai_build"
  spec.version = RailsAiBuild::VERSION
  spec.authors = ["Shahnawaz & Rails AI Build Contributors"]
  spec.email = ["hello@rails-ai-build.dev"]

  spec.summary = "Cursor-like AI agent integration for Rails applications"
  spec.description = <<~DESC
    rails_ai_build brings AI coding agents into any Rails application.
    Create agents that read, search, and modify your codebase using multiple
    AI model providers (OpenAI, Anthropic, custom). Includes a Rails engine
    with REST API, Host Safety, generator-first routing, and extensible tools.
  DESC
  spec.homepage = "https://github.com/shahnawaz-ror/Rails-Ai-Build"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  # Explicit runtime package — no landing/, packages/, server/, or specs.
  spec.files = Dir.chdir(__dir__) do
    runtime = Dir[
      "{app,config,db,lib}/**/*",
      "LICENSE*",
      "README*",
      "CHANGELOG*",
      "SECURITY*",
      "rails_ai_build.gemspec"
    ]
    runtime.select { |f| File.file?(f) }
  end

  spec.require_paths = ["lib"]
  spec.extra_rdoc_files = %w[README.md CHANGELOG.md]

  spec.add_dependency "rails", ">= 7.0"
  spec.add_dependency "activesupport", ">= 7.0"
  spec.add_dependency "activerecord", ">= 7.0"
  spec.add_dependency "activejob", ">= 7.0"

  spec.add_development_dependency "appraisal", "~> 2.5"
  spec.add_development_dependency "combustion", "~> 1.3"
  spec.add_development_dependency "rspec", "~> 3.12"
  spec.add_development_dependency "rspec-rails", "~> 6.0"
  spec.add_development_dependency "rubocop", "~> 1.60"
  spec.add_development_dependency "rubocop-performance", "~> 1.20"
  spec.add_development_dependency "rubocop-rails", "~> 2.24"
  spec.add_development_dependency "rubocop-rspec", "~> 2.26"
  spec.add_development_dependency "simplecov", "~> 0.22"
  spec.add_development_dependency "simplecov-cobertura", "~> 3.2"
  spec.add_development_dependency "webmock", "~> 3.19"
end
