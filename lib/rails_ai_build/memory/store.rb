# frozen_string_literal: true

module RailsAiBuild
  module Memory
    # Agent memory — persists project context across sessions (Pro+ feature)
    class Store
      class << self
        def load(workspace:)
          Plans.check!(:agent_memory)
          path = memory_file(workspace)
          return {} unless path.exist?

          JSON.parse(path.read)
        rescue JSON::ParserError
          {}
        end

        def save(workspace:, data:)
          Plans.check!(:agent_memory)
          path = memory_file(workspace)
          path.dirname.mkpath
          path.write(JSON.pretty_generate(data))
        end

        def remember(workspace:, key:, value:)
          data = load(workspace: workspace)
          data[key.to_s] = value
          save(workspace: workspace, data: data)
        end

        def recall(workspace:, key:)
          load(workspace: workspace)[key.to_s]
        end

        def context_for(workspace:)
          data = load(workspace: workspace)
          return nil if data.empty?

          <<~CONTEXT
            ## Project Memory
            #{data.map { |k, v| "- #{k}: #{v}" }.join("\n")}
          CONTEXT
        end

        private

        def memory_file(workspace)
          workspace.join(".rails_ai_build", "memory.json")
        end
      end
    end
  end
end

require "json"
