# frozen_string_literal: true

ENV["RAILS_ENV"] ||= "test"

require "rails_ai_build"

RSpec.configure do |config|
  config.before do
    RailsAiBuild.reset_configuration!
    Analytics.reset! if RailsAiBuild::Analytics.respond_to?(:reset!)
    TokenUsage.reset!
    Changes::Store.clear!
  end

  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.filter_run_when_matching :focus
  config.example_status_persistence_file_path = "spec/examples.txt"
  config.disable_monkey_patching!
  config.order = :random
  Kernel.srand config.seed
end
