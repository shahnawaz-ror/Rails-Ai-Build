# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"

begin
  require "rubocop/rake_task"
  RuboCop::RakeTask.new
rescue LoadError
  # RuboCop is optional until development gems are installed.
end

RSpec::Core::RakeTask.new(:spec)

namespace :spec do
  desc "Run unit specs (no Rails boot)"
  RSpec::Core::RakeTask.new(:unit) do |t|
    t.pattern = "spec/{rails_ai_build,rails_ai_build/**/*,generators}/**/*_spec.rb"
    t.rspec_opts = "--tag ~type:request --tag ~type:integration"
  end

  desc "Run request/integration specs (requires Combustion)"
  RSpec::Core::RakeTask.new(:integration) do |t|
    t.pattern = "spec/{requests,integration}/**/*_spec.rb"
  end
end

desc "Run RuboCop and RSpec"
task default: %i[rubocop spec]

desc "CI gate: style + full test suite"
task ci: %i[rubocop spec]
