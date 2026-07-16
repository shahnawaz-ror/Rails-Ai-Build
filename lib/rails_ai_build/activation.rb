# frozen_string_literal: true

require "securerandom"
require "openssl"
require "json"

module RailsAiBuild
  # Day-1 activation brain: encrypted keys, durable plan, settings token, wizard state.
  module Activation
    module_function

    def table_ready?
      return false unless defined?(ActiveRecord::Base) && ActiveRecord::Base.connected?

      ActiveRecord::Base.connection.data_source_exists?("rails_ai_build_activations")
    rescue StandardError
      false
    end

    def record
      return nil unless table_ready?

      ActivationRecord.instance_row
    end

    def load_into_configuration!
      row = record
      return unless row

      config = RailsAiBuild.configuration
      keys = row.decrypted_api_keys
      keys.each { |provider, key| config.api_keys[provider.to_sym] = key if key.present? }
      config.cloud_api_key = row.decrypted_cloud_api_key if row.decrypted_cloud_api_key.present?

      if row.plan.present? && Plans::PLANS.key?(row.plan.to_sym)
        config.plan = row.plan.to_sym
        config.diff_preview = true if Plans.feature?(:diff_preview)
        config.audit_enabled = true if Plans.feature?(:audit_log)
      end

      config.license_key = row.license_token if row.license_token.present?
      config.wizard_completed = row.wizard_completed
      config.settings_token_digest = row.settings_token_digest
    rescue StandardError => e
      warn_log("load failed: #{e.message}")
    end

    def status
      config = RailsAiBuild.configuration
      keys = configured_providers
      {
        activated: keys.any? || config.cloud_api_key.present? || config.license_key.present?,
        wizard_completed: config.wizard_completed,
        needs_wizard: !config.wizard_completed && keys.empty? && config.cloud_api_key.blank?,
        api_keys_configured: {
          openai: config.api_key_for(:openai).present?,
          anthropic: config.api_key_for(:anthropic).present?,
          nvidia: config.api_key_for(:nvidia).present?,
          cloud: config.cloud_api_key.present?
        },
        providers: keys,
        plan: config.plan,
        plan_name: Plans.current[:name],
        license_present: config.license_key.present?,
        entitlement_source: entitlement_source,
        settings_token_required: settings_token_required?,
        encryption_available: Secrets::Encryptor.available?,
        durable_store: table_ready?,
        upgrade_url: Plans::UPGRADE_URL
      }
    end

    def configured_providers
      config = RailsAiBuild.configuration
      %i[openai anthropic nvidia].select { |p| config.api_key_for(p).present? }.tap do |list|
        list << :cloud if config.cloud_api_key.present?
      end
    end

    def entitlement_source
      row = record
      return row.entitlement_source.to_sym if row&.entitlement_source.present?
      return :license if RailsAiBuild.configuration.license_key.present?
      return :config if RailsAiBuild.configuration.plan && RailsAiBuild.configuration.plan != :free

      :free
    end

    def persist_api_keys!(keys_hash)
      ensure_store!
      row = record
      merged = row.decrypted_api_keys.merge(normalize_keys(keys_hash))
      merged.delete_if { |_k, v| v.nil? || v.to_s.strip.empty? }

      row.encrypted_api_keys = Secrets::Encryptor.encrypt(JSON.generate(merged))
      row.save!

      merged.each { |provider, key| RailsAiBuild.configuration.api_keys[provider.to_sym] = key }
      RailsAiBuild.configuration.apply_env_providers! if merged.empty?
      status
    end

    def persist_cloud_api_key!(key)
      ensure_store!
      row = record
      row.encrypted_cloud_api_key = key.present? ? Secrets::Encryptor.encrypt(key.to_s) : nil
      row.save!
      RailsAiBuild.configuration.cloud_api_key = key.presence
      status
    end

    def apply_license!(verified)
      ensure_store!
      row = record
      row.license_token = verified[:raw]
      row.plan = verified[:plan].to_s
      row.entitlement_source = "license"
      row.license_org = verified[:org]
      row.license_expires_at = verified[:expires_at] ? Time.at(verified[:expires_at].to_i) : nil
      row.save!

      config = RailsAiBuild.configuration
      config.plan = verified[:plan].to_sym
      config.license_key = verified[:raw]
      config.seat_limit = verified[:seats].to_i if verified[:seats].to_i.positive?
      config.diff_preview = true if Plans.feature?(:diff_preview)
      config.audit_enabled = true if Plans.feature?(:audit_log)
      Plans.apply_limits!
      status
    end

    def apply_plan!(plan, source: "billing")
      plan = plan.to_sym
      raise ConfigurationError, "Unknown plan: #{plan}" unless Plans::PLANS.key?(plan)

      if table_ready?
        row = record
        row.plan = plan.to_s
        row.entitlement_source = source.to_s
        row.save!
      end

      RailsAiBuild.configuration.plan = plan
      RailsAiBuild.configuration.diff_preview = Plans.feature?(:diff_preview)
      RailsAiBuild.configuration.audit_enabled = true if Plans.feature?(:audit_log)
      Plans.apply_limits!
      status
    end

    def complete_wizard!
      RailsAiBuild.configuration.wizard_completed = true
      return status unless table_ready?

      row = record
      row.wizard_completed = true
      row.save!
      status
    end

    def bootstrap_settings_token!
      ensure_store!
      row = record
      if row.settings_token_digest.present?
        raise SecurityError, "Settings token already issued. Set RAILS_AI_BUILD_SETTINGS_TOKEN or rotate via rake."
      end

      token = SecureRandom.hex(24)
      row.settings_token_digest = digest_token(token)
      row.save!
      RailsAiBuild.configuration.settings_token_digest = row.settings_token_digest
      token
    end

    def rotate_settings_token!
      ensure_store!
      token = SecureRandom.hex(24)
      row = record
      row.settings_token_digest = digest_token(token)
      row.save!
      RailsAiBuild.configuration.settings_token_digest = row.settings_token_digest
      token
    end

    def valid_settings_token?(token)
      return true if bypass_settings_auth?

      expected = RailsAiBuild.configuration.settings_token_digest
      expected = record&.settings_token_digest if expected.blank? && table_ready?
      env_token = ENV["RAILS_AI_BUILD_SETTINGS_TOKEN"].presence

      return ActiveSupport::SecurityUtils.secure_compare(token.to_s, env_token) if env_token && expected.blank?
      return false if expected.blank? || token.blank?

      ActiveSupport::SecurityUtils.secure_compare(digest_token(token), expected)
    end

    def settings_token_required?
      return false if bypass_settings_auth?

      ENV["RAILS_AI_BUILD_SETTINGS_TOKEN"].present? ||
        RailsAiBuild.configuration.settings_token_digest.present? ||
        (table_ready? && record&.settings_token_digest.present?)
    end

    def bypass_settings_auth?
      return true if ENV["RAILS_AI_BUILD_ALLOW_OPEN_SETTINGS"] == "1"
      return true if defined?(Rails) && rails_env_local? && ENV["RAILS_AI_BUILD_SETTINGS_TOKEN"].blank? &&
                     RailsAiBuild.configuration.settings_token_digest.blank? &&
                     !(table_ready? && record&.settings_token_digest.present?)

      false
    end

    def ensure_store!
      raise ConfigurationError, "Activation store unavailable — run migrations" unless table_ready?
    end

    def digest_token(token)
      OpenSSL::Digest::SHA256.hexdigest("rab-settings:#{token}")
    end

    def normalize_keys(keys_hash)
      hash = keys_hash.respond_to?(:to_unsafe_h) ? keys_hash.to_unsafe_h : keys_hash.to_h
      hash.each_with_object({}) do |(k, v), acc|
        key = k.to_s.downcase.to_sym
        next unless %i[openai anthropic nvidia].include?(key)

        acc[key] = v
      end
    end

    def rails_env_local?
      return Rails.env.local? if Rails.env.respond_to?(:local?)

      Rails.env.development? || Rails.env.test?
    end

    def warn_log(message)
      if defined?(Rails) && Rails.logger
        Rails.logger.warn("[rails_ai_build] Activation #{message}")
      end
    end
  end
end
