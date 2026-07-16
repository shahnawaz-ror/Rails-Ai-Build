# frozen_string_literal: true

require "json"
require "securerandom"
require "fileutils"

module RailsAiBuild
  module Memory
    # Agent memory — persists project context across sessions (Pro+ feature).
    # Caps keys/values/file size so a poisoned memory.json cannot OOM or prompt-bomb agents.
    class Store
      MAX_KEYS = 256
      MAX_VALUE_BYTES = 4_096
      MAX_FILE_BYTES = 256_000
      MAX_CONTEXT_ENTRIES = 40

      class << self
        def load(workspace:)
          Plans.check!(:agent_memory)
          path = memory_file(workspace)
          return {} unless path.exist?
          return {} if path.size > MAX_FILE_BYTES

          data = JSON.parse(path.read)
          return {} unless data.is_a?(Hash)

          sanitize_hash(data)
        rescue JSON::ParserError, Errno::ENOENT
          {}
        end

        def save(workspace:, data:)
          Plans.check!(:agent_memory)
          path = memory_file(workspace)
          path.dirname.mkpath
          payload = JSON.pretty_generate(sanitize_hash(data))
          raise AgentError, "Memory file exceeds #{MAX_FILE_BYTES} bytes" if payload.bytesize > MAX_FILE_BYTES

          tmp = path.sub_ext(".json.tmp-#{Process.pid}-#{SecureRandom.hex(4)}")
          File.open(tmp, File::WRONLY | File::CREAT | File::TRUNC, 0o600) do |io|
            io.flock(File::LOCK_EX)
            io.write(payload)
            io.flush
          end
          File.rename(tmp.to_s, path.to_s)
        rescue StandardError
          FileUtils.rm_f(tmp) if defined?(tmp) && tmp
          raise
        end

        def remember(workspace:, key:, value:)
          data = load(workspace: workspace)
          data[key.to_s] = clamp_value(value)
          save(workspace: workspace, data: data)
        end

        def recall(workspace:, key:)
          load(workspace: workspace)[key.to_s]
        end

        def context_for(workspace:)
          data = load(workspace: workspace)
          return nil if data.empty?

          entries = data.first(MAX_CONTEXT_ENTRIES)
          <<~CONTEXT
            ## Project Memory
            #{entries.map { |k, v| "- #{k}: #{v}" }.join("\n")}
          CONTEXT
        end

        private

        def memory_file(workspace)
          workspace.join(".rails_ai_build", "memory.json")
        end

        def sanitize_hash(data)
          cleaned = {}
          data.each do |key, value|
            break if cleaned.size >= MAX_KEYS

            cleaned[key.to_s] = clamp_value(value)
          end
          cleaned
        end

        def clamp_value(value)
          str = value.is_a?(String) ? value : value.to_s
          return str if str.bytesize <= MAX_VALUE_BYTES

          str.byteslice(0, MAX_VALUE_BYTES)
        end
      end
    end
  end
end
