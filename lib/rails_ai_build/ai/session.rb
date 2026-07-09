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
        auto_title! if @title.nil? && message.role == :user
      end

      def to_h
        {
          id: id,
          title: title || default_title,
          model: model,
          provider: provider,
          message_count: messages.size,
          created_at: created_at&.iso8601,
          metadata: metadata,
          preview: messages.last&.content.to_s[0, 120]
        }
      end

      def messages_preview
        messages.map do |msg|
          {
            role: msg.role,
            content: msg.content.to_s[0, 500],
            name: msg.name
          }
        end
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

        def all
          store.values.sort_by(&:created_at).reverse
        end

        def destroy(id)
          store.delete(id.to_s)
        end

        def reset!
          @store = {}
        end

        private

        def store
          @store ||= {}
        end
      end

      private

      def auto_title!
        first = messages.find { |m| m.role == :user }&.content.to_s
        @title = first[0, 48] if first.present?
      end

      def default_title
        "Thread #{id.to_s[0, 8]}"
      end
    end
  end
end
