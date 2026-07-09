# frozen_string_literal: true

Rails.application.routes.draw do
  mount RailsAiBuild::Engine => "/rails_ai_build"
end
