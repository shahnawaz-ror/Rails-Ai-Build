# frozen_string_literal: true

require "openssl"
require "base64"

module RailsAiBuild
  module Secrets
    # Encrypts API keys / license blobs at rest using ActiveSupport::MessageEncryptor
    # keyed from Rails secret_key_base or RAILS_AI_BUILD_SECRET.
    class Encryptor
      PREFIX = "rab1"

      class << self
        def encrypt(plaintext)
          return nil if plaintext.nil?

          "#{PREFIX}:#{encryptor.encrypt_and_sign(plaintext.to_s)}"
        end

        def decrypt(ciphertext)
          return nil if ciphertext.nil? || ciphertext.to_s.empty?
          return ciphertext.to_s unless ciphertext.to_s.start_with?("#{PREFIX}:")

          encryptor.decrypt_and_verify(ciphertext.to_s.delete_prefix("#{PREFIX}:"))
        rescue ActiveSupport::MessageEncryptor::InvalidMessage, ArgumentError
          nil
        end

        def available?
          secret_key.present?
        end

        private

        def encryptor
          @encryptor ||= begin
            require "active_support"
            require "active_support/message_encryptor"
            key = ActiveSupport::KeyGenerator.new(secret_key).generate_key("rails-ai-build-secrets", 32)
            ActiveSupport::MessageEncryptor.new(key)
          end
        end

        def secret_key
          ENV["RAILS_AI_BUILD_SECRET"].presence ||
            (defined?(Rails) && Rails.application&.secret_key_base).presence ||
            ENV["SECRET_KEY_BASE"].presence
        end

        def reset!
          @encryptor = nil
        end
      end
    end
  end
end
