# frozen_string_literal: true

module RailsAiBuild
  module Tools
    class ReadSettingsTool < BaseTool
      name 'read_settings'
      description 'Read safe Rails configuration values using dot notation (e.g. action_mailer.delivery_method).'
      parameters type: 'object',
                 properties: {
                   keys: {
                     type: 'array',
                     items: { type: 'string' },
                     description: 'Config keys in dot notation. Omit for a safe summary.'
                   }
                 },
                 required: []

      BLOCKED_KEY_PATTERNS = [
        /secret/i, /password/i, /credential/i, /key_base/i, /token/i, /api_key/i
      ].freeze

      SAFE_SUMMARY_KEYS = %w[
        cache_classes
        eager_load
        consider_all_requests_local
        force_ssl
        log_level
      ].freeze

      def execute(args)
        keys = Array(args['keys']).map(&:to_s).reject(&:empty?)
        keys = SAFE_SUMMARY_KEYS if keys.empty?

        blocked, allowed = keys.partition { |k| blocked_key?(k) }

        values = allowed.index_with do |key|
          read_key(key)
        end

        {
          values: values,
          blocked_keys: blocked,
          source: RailsContext.rails_loaded? ? 'rails.application.config' : 'config files'
        }
      end

      private

      def blocked_key?(key)
        BLOCKED_KEY_PATTERNS.any? { |pattern| key.match?(pattern) }
      end

      def read_key(key)
        if RailsContext.rails_loaded?
          dig_config(Rails.application.config, key.split('.'))
        else
          read_from_files(key)
        end
      rescue StandardError => e
        { error: e.message }
      end

      def dig_config(obj, parts)
        return obj if parts.empty?

        part = parts.shift
        value = obj.respond_to?(part) ? obj.public_send(part) : nil
        parts.empty? ? serialize_value(value) : dig_config(value, parts)
      end

      def read_from_files(key)
        app_rb = workspace.join('config/application.rb')
        return nil unless app_rb.exist?

        pattern = key.tr('.', '_')
        app_rb.read.lines.find { |line| line.include?(pattern) }&.strip
      end

      def serialize_value(value)
        case value
        when Symbol, String, Numeric, TrueClass, FalseClass, NilClass then value
        else value.to_s
        end
      end
    end
  end
end
