# frozen_string_literal: true

require "securerandom"
require "monitor"
require "json"
require "fileutils"

module RailsAiBuild
  module Ai
    # Multi-turn conversation thread — Claude/Cursor-style session.
    # In-memory for speed, with JSON persistence under .rails_ai_build/sessions/
    # so chats survive page refresh and server restart (Free-tier friendly).
    class Session
      attr_reader :id, :title, :model, :provider, :messages, :created_at, :metadata
      attr_writer :title, :updated_at

      def initialize(id: nil, title: nil, model: nil, provider: nil, metadata: {}, created_at: nil, updated_at: nil)
        @id = id || SecureRandom.uuid
        @title = title
        @model = model || RailsAiBuild.configuration.default_model
        @provider = (provider || RailsAiBuild.configuration.default_provider).to_sym
        @messages = []
        @created_at = created_at || Time.zone.now
        @updated_at = updated_at || @created_at
        @metadata = metadata || {}
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
        if message.respond_to?(:role) && message.role.to_sym == :user
          auto_title! if @title.nil? || wrapper_title?(@title)
        end
        @updated_at = Time.zone.now
        self.class.persist!(self)
      end

      def touch!
        @updated_at = Time.zone.now
        self.class.persist!(self)
      end

      def to_h
        refresh_title!
        {
          id: id,
          title: title || default_title,
          model: model,
          provider: provider,
          message_count: messages.size,
          created_at: created_at&.iso8601,
          updated_at: (@updated_at || created_at)&.iso8601,
          metadata: metadata,
          preview: last_user_or_assistant_preview
        }
      end

      def messages_preview
        messages_for_client(limit: 500)
      end

      # Fuller transcript for IDE history UI (skips system + noisy tool payloads).
      def messages_for_client(limit: 8_000)
        out = []
        messages.each do |msg|
          role = msg.role.to_sym
          next if role == :system

          content = msg.content.to_s
          content = strip_routing_wrappers(content) if role == :user
          if role == :tool
            content = content[0, 240]
            content = "#{content}…" if msg.content.to_s.length > 240
          else
            content = content[0, limit]
          end

          # Collapse consecutive duplicate assistant replies (looping models).
          if role == :assistant && out.last && out.last[:role] == "assistant" && out.last[:content] == content
            next
          end

          out << {
            role: role.to_s,
            content: content,
            name: msg.name
          }
        end
        out
      end

      def refresh_title!
        return unless @title.nil? || wrapper_title?(@title)

        auto_title!
        self.class.persist!(self) if @title.present? && !wrapper_title?(@title)
      end

      def empty?
        messages.none? { |m| %i[user assistant].include?(m.role.to_sym) && m.content.to_s.strip.present? }
      end

      def junk?
        empty? || wrapper_title?(@title)
      end

      class << self
        MAX_SESSIONS = 2_000

        def create(**opts)
          session = new(**opts)
          mutex.synchronize do
            store[session.id] = session
            persist_unlocked!(session)
            evict! if store.size > max_sessions
          end
          session
        end

        def find(id)
          return nil if id.to_s.empty?

          mutex.synchronize do
            store[id.to_s] || load_from_disk_unlocked!(id.to_s)
          end
        end

        def all
          mutex.synchronize do
            hydrate_from_disk!
            store.values.sort_by { |s| s.instance_variable_get(:@updated_at) || s.created_at }.reverse
          end
        end

        def destroy(id)
          mutex.synchronize do
            store.delete(id.to_s)
            path = disk_path(id)
            path.delete if path.exist?
          end
        end

        # Drop empty threads and ones still stuck on wrapper titles after refresh.
        def prune_junk!
          removed = []
          all.each do |session|
            session.refresh_title!
            next unless session.empty? || wrapper_title?(session.title)

            destroy(session.id)
            removed << session.id
          end
          removed
        end

        def reset!
          mutex.synchronize { store.clear }
        end

        def persist!(session)
          mutex.synchronize { persist_unlocked!(session) }
        end

        def wrapper_title?(title)
          title.to_s.match?(/\A#\s*(Task|Composer mode)\b/i)
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

          store.sort_by { |_id, s| s.instance_variable_get(:@updated_at) || s.created_at }
               .first(overflow)
               .each do |id, _|
            store.delete(id)
            path = disk_path(id)
            path.delete if path.exist?
          end
        end

        def sessions_dir
          RailsAiBuild.configuration.workspace_path.join(".rails_ai_build", "sessions")
        end

        def disk_path(id)
          safe = id.to_s.gsub(/[^a-zA-Z0-9\-_]/, "")
          sessions_dir.join("#{safe}.json")
        end

        def hydrate_from_disk!
          dir = sessions_dir
          return unless dir.directory?

          dir.glob("*.json").each do |path|
            id = path.basename(".json").to_s
            next if store.key?(id)

            load_from_disk_unlocked!(id)
          end
        rescue StandardError
          nil
        end

        def load_from_disk_unlocked!(id)
          path = disk_path(id)
          return nil unless path.file?

          data = JSON.parse(path.read)
          return nil unless data.is_a?(Hash)

          session = from_payload(data)
          store[session.id] = session
          session
        rescue JSON::ParserError, Errno::ENOENT, TypeError
          nil
        end

        def from_payload(data)
          session = new(
            id: data["id"],
            title: data["title"],
            model: data["model"],
            provider: data["provider"],
            metadata: data["metadata"] || {},
            created_at: parse_time(data["created_at"]),
            updated_at: parse_time(data["updated_at"]) || parse_time(data["created_at"])
          )
          Array(data["messages"]).each do |raw|
            next unless raw.is_a?(Hash)

            session.messages << Agents::Message.new(
              role: (raw["role"] || "user").to_sym,
              content: raw["content"].to_s,
              tool_calls: raw["tool_calls"],
              tool_call_id: raw["tool_call_id"],
              name: raw["name"]
            )
          end
          session
        end

        def parse_time(value)
          return value if value.is_a?(Time)
          return nil if value.to_s.empty?

          Time.zone.parse(value.to_s)
        rescue StandardError
          nil
        end

        def persist_unlocked!(session)
          dir = sessions_dir
          dir.mkpath
          path = disk_path(session.id)
          payload = JSON.pretty_generate(session_payload(session))
          tmp = path.sub_ext(".json.tmp-#{Process.pid}-#{SecureRandom.hex(4)}")
          File.open(tmp, File::WRONLY | File::CREAT | File::TRUNC, 0o600) do |io|
            io.write(payload)
            io.flush
          end
          File.rename(tmp.to_s, path.to_s)
        rescue StandardError
          FileUtils.rm_f(tmp) if defined?(tmp) && tmp
          # Persistence is best-effort — never break the agent turn
          nil
        end

        def session_payload(session)
          {
            "id" => session.id,
            "title" => session.title,
            "model" => session.model,
            "provider" => session.provider.to_s,
            "created_at" => session.created_at&.iso8601,
            "updated_at" => (session.instance_variable_get(:@updated_at) || session.created_at)&.iso8601,
            "metadata" => session.metadata,
            "messages" => session.messages.map { |m| serialize_message(m) }
          }
        end

        def serialize_message(msg)
          h = {
            "role" => msg.role.to_s,
            "content" => msg.content.to_s
          }
          # Keep tool payloads short on disk
          if msg.role.to_sym == :tool && h["content"].bytesize > 2_000
            h["content"] = "#{h['content'].byteslice(0, 2_000)}…"
          end
          h["name"] = msg.name if msg.name
          h["tool_call_id"] = msg.tool_call_id if msg.tool_call_id
          h
        end
      end

      private

      def last_user_or_assistant_preview
        msg = messages.reverse.find { |m| %i[user assistant].include?(m.role.to_sym) && m.content.to_s.strip.present? }
        return "" unless msg

        text = msg.role.to_sym == :user ? strip_routing_wrappers(msg.content) : msg.content.to_s
        text[0, 120]
      end

      def auto_title!
        first = messages.find { |m| m.role.to_sym == :user }&.content.to_s
        first = strip_routing_wrappers(first)
        @title = first[0, 48] if first.present?
      end

      # Build/Composer wrap the real ask in "# Task" / "# Composer mode" headers —
      # don't use those as the thread title (causes identical jumpy Threads).
      def strip_routing_wrappers(text)
        s = text.to_s.dup
        s.sub!(/\A#\s*Composer mode[^\n]*\n(?:.*\n){0,4}/i, "")
        s.sub!(/\A#\s*Task\s*\n+/i, "")
        s.sub!(/\A\[RailsAiBuild routing\][\s\S]*\z/i, "")
        s.strip
      end

      def wrapper_title?(title)
        title.to_s.match?(/\A#\s*(Task|Composer mode)\b/i)
      end

      def default_title
        "Thread #{id.to_s[0, 8]}"
      end
    end
  end
end
