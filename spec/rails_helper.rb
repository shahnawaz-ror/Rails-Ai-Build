# frozen_string_literal: true

require "spec_helper"
require "combustion"

unless defined?(RAILS_AI_BUILD_COMBUSTION_BOOTED)
  RAILS_AI_BUILD_COMBUSTION_BOOTED = true

  Combustion.path = "spec/internal"
  Combustion.initialize! :active_record, :action_controller, :action_view, :active_job,
                         database_migrate: false

  require "rails_ai_build/engine"
  load RailsAiBuild::Engine.root.join("config/routes.rb")

  require RailsAiBuild::Engine.root.join("app/models/rails_ai_build/application_record.rb")
  Dir[RailsAiBuild::Engine.root.join("app/models/**/*.rb")].sort.each do |file|
    require file unless file.end_with?("application_record.rb")
  end
  Dir[RailsAiBuild::Engine.root.join("app/jobs/**/*.rb")].sort.each { |file| require file }
  Dir[RailsAiBuild::Engine.root.join("app/controllers/rails_ai_build/concerns/**/*.rb")].sort.each { |file| require file }
  require RailsAiBuild::Engine.root.join("app/controllers/rails_ai_build/application_controller.rb")
  Dir[RailsAiBuild::Engine.root.join("app/controllers/**/*.rb")].sort.each do |file|
    next if file.include?("/concerns/")
    next if file.end_with?("application_controller.rb")

    require file
  end

  ActionController::Base.prepend_view_path(RailsAiBuild::Engine.root.join("app/views"))

  require_relative "support/database"
  load Rails.root.join("db/schema.rb") unless ActiveRecord::Base.connection.table_exists?("rails_ai_build_agents")

  Rails.application.reload_routes!
end

require "rspec/rails"

RSpec.configure do |config|
  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!

  config.before do
    RailsAiBuild.reset_configuration!
    RailsAiBuild.configuration.auto_mount = false
    RailsAiBuild::Models::Registry.reset!
    RailsAiBuild::Models::Registry.register_defaults
    RailsAiBuild::Ai::Session.reset!
    RailsAiBuild::Tasks::Queue.reset!
    RailsAiBuild::RateLimit.reset!
    ActiveJob::Base.queue_adapter = :test
    Database.reset! if defined?(Database)
    RailsAiBuild::Changes::Store.clear!
  end
end
