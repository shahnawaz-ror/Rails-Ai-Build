# frozen_string_literal: true

require 'securerandom'

module RailsAiBuild
  module Ai
    # Multi-turn conversation thread — Claude/Cursor-style session.
    class Session
      attr_reader :id, :title, :model, :provider, :messages, :created_at, :metadata

      def initialize(id: nil, title: nil, model: nil, provider: nil, metadata: {})
        @id = id || SecureRandom.uuid
        @title = title
        @model = model || RailsAiBuild.configuration.default_model
        @provider = (provider || RailsAiBuild.configuration.default_provider).to_sym
        @messages = []
        @created_at = Time.zone.now
        @metadata = metadata
      end

      def add_message(message)
        @messages << message
      end

      def to_h
        {
          id: id,
          title: title,
          model: model,
          provider: provider,
          message_count: messages.size,
          created_at: created_at&.iso8601,
          metadata: metadata
        }
      end

      class << self
        def create(**opts)
          session = new(**opts)
          store[session.id] = session
          session
        end

        def find(id)
          store[id.to_s]
        end

        def reset!
          @store = {}
        end

        private

        def store
          @store ||= {}
        end
      end
    end
  end
end
