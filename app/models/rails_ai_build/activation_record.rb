# frozen_string_literal: true

module RailsAiBuild
  class ActivationRecord < ApplicationRecord
    self.table_name = "rails_ai_build_activations"

    def self.instance_row
      first || create!(plan: "free", entitlement_source: "free", wizard_completed: false)
    end

    def decrypted_api_keys
      raw = Secrets::Encryptor.decrypt(encrypted_api_keys)
      return {} if raw.blank?

      JSON.parse(raw).transform_keys(&:to_sym)
    rescue JSON::ParserError
      {}
    end

    def decrypted_cloud_api_key
      Secrets::Encryptor.decrypt(encrypted_cloud_api_key)
    end
  end
end
