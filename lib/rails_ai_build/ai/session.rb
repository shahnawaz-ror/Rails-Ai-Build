# frozen_string_literal: true

require "securerandom"
require "monitor"

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

      MAX_MESSAGES = 200
      MAX_MESSAGE_BYTES = 100_000

      def add_message(message)
        content = message.respond_to?(:content) ? message.content.to_s : message.to_s
        if content.bytesize > MAX_MESSAGE_BYTES
          raise AgentError, "Session message exceeds #{MAX_MESSAGE_BYTES} bytes"
        end

        @messages << message
        @messages.shift while @messages.size > MAX_MESSAGES
        auto_title! if @title.nil? && message.respond_to?(:role) && message.role == :user
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
        MAX_SESSIONS = 2_000

        def create(**opts)
          session = new(**opts)
          mutex.synchronize do
            store[session.id] = session
            evict! if store.size > max_sessions
          end
          session
        end

        def find(id)
          mutex.synchronize { store[id.to_s] }
        end

        def all
          mutex.synchronize { store.values.sort_by(&:created_at).reverse }
        end

        def destroy(id)
          mutex.synchronize { store.delete(id.to_s) }
        end

        def reset!
          mutex.synchronize { store.clear }
        end

        private

        def mutex
          @mutex ||= Monitor.new
        end

        def store
          @store ||= {}
        end

        def max_sessions
          (RailsAiBuild.configuration.max_ai_sessions || MAX_SESSIONS).to_i
        end

        def evict!
          overflow = store.size - max_sessions
          return if overflow <= 0

          store.sort_by { |_id, s| s.created_at }.first(overflow).each { |id, _| store.delete(id) }
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
