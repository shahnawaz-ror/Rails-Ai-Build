# frozen_string_literal: true

require "spec_helper"
require "combustion"

unless defined?(RAILS_AI_BUILD_COMBUSTION_BOOTED)
  RAILS_AI_BUILD_COMBUSTION_BOOTED = true

  Combustion.path = "spec/internal"
  Combustion.initialize! :action_controller, :action_view

  require "rails_ai_build/engine"
  load RailsAiBuild::Engine.root.join("config/routes.rb")

  Dir[RailsAiBuild::Engine.root.join("app/controllers/**/*.rb")].sort.each { |file| require file }

  Rails.application.reload_routes!
end

require "rspec/rails"

RSpec.configure do |config|
  config.use_transactional_fixtures = false
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!

  config.before do
    RailsAiBuild.reset_configuration!
    RailsAiBuild.configuration.auto_mount = false
    RailsAiBuild::Models::Registry.reset!
    RailsAiBuild::Models::Registry.register_defaults
  end
end
