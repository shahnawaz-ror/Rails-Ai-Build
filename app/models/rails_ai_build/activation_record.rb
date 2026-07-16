# frozen_string_literal: true

module RailsAiBuild
  class ActivationRecord < ApplicationRecord
    self.table_name = "rails_ai_build_activations"

    SINGLETON_KEY = "default"

    def self.instance_row
      if singleton_guarded?
        find_by(singleton_key: SINGLETON_KEY) || create_singleton!
      else
        first || create_singleton!
      end
    rescue ActiveRecord::RecordNotUnique, ActiveRecord::StatementInvalid
      singleton_guarded? ? find_by!(singleton_key: SINGLETON_KEY) : first!
    end

    def self.singleton_guarded?
      column_names.include?("singleton_key")
    end

    def self.create_singleton!
      attrs = {
        plan: "free",
        entitlement_source: "free",
        wizard_completed: false
      }
      attrs[:singleton_key] = SINGLETON_KEY if singleton_guarded?
      create!(attrs)
    end
    private_class_method :create_singleton!

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
