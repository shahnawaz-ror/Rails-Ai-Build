# frozen_string_literal: true

module RailsAiBuild
  module Tools
    class BaseTool
      class << self
        attr_reader :tool_name, :tool_description, :tool_parameters

        def name(value = nil)
          return @tool_name if value.nil?
          @tool_name = value.to_s
        end

        def description(value = nil)
          return @tool_description if value.nil?
          @tool_description = value
        end

        def parameters(schema = nil)
          return @tool_parameters if schema.nil?
          @tool_parameters = schema
        end

        def definition
          {
            name: tool_name,
            description: tool_description,
            parameters: tool_parameters
          }
        end
      end

      def initialize(workspace:)
        @workspace = workspace
      end

      def call(arguments)
        execute(arguments.transform_keys(&:to_s))
      rescue SecurityError
        raise
      rescue StandardError => e
        { error: e.message }
      end

      protected

      attr_reader :workspace

      def resolve_path(path)
        raise ArgumentError, "path is required" if path.nil? || path.to_s.strip.empty?

        full = workspace.join(path.to_s.sub(%r{\A/}, ""))
        resolved = full.expand_path

        unless resolved.to_s.start_with?(workspace.expand_path.to_s)
          raise SecurityError, "Path escapes workspace: #{path}"
        end

        resolved
      end
    end
  end
end
