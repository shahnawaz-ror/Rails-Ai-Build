# frozen_string_literal: true

module RailsAiBuild
  class ModelConfig < ApplicationRecord
    self.table_name = "rails_ai_build_model_configs"

    validates :name, presence: true, uniqueness: true
    validates :provider, presence: true

    scope :enabled, -> { where(enabled: true) }

    def to_provider
      options = (config || {}).symbolize_keys
      options[:api_key] ||= RailsAiBuild.configuration.api_key_for(provider)
      Models::Registry.build(provider, **options)
    end
  end
end
