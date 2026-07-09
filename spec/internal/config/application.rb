# frozen_string_literal: true

require "rails"
require "rails_ai_build"

RailsAiBuild.configuration.auto_mount = false

Bundler.require :default, :development

module Internal
  class Application < Rails::Application
    config.load_defaults 7.0
    config.eager_load = false
    config.hosts.clear
    config.consider_all_requests_local = true
    config.secret_key_base = "0" * 64
    config.cache_classes = true
    config.action_dispatch.show_exceptions = :rescuable
  end
end
