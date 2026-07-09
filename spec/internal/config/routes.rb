# frozen_string_literal: true

require "rails_ai_build/engine"

Rails.application.routes.draw do
  mount RailsAiBuild::Engine => "/rails_ai_build", as: :mounted_rails_ai_build
end
