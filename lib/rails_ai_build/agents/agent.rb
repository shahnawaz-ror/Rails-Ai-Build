# frozen_string_literal: true

module RailsAiBuild
  module Agents
    class Agent
      attr_reader :name, :provider, :provider_name, :model, :system_prompt, :tools, :workspace

      DEFAULT_SYSTEM_PROMPT = <<~PROMPT.freeze
        You are an AI coding agent integrated into a Rails application via the rails_ai_build gem.
        You can read, search, and modify files in the application using the provided tools.
        Follow existing code conventions. Make minimal, focused changes. Explain your reasoning briefly.
        When modifying code, read relevant files first before writing changes.
        Tool paths are relative to the Rails app root. Use "." or omit path to list the project root.
        Never pass "workspace" as a directory — that is not a folder inside the app.
      PROMPT

      def initialize(
        name: "default",
        provider: nil,
        model: nil,
        system_prompt: nil,
        tools: nil,
        workspace: nil
      )
        @name = name
        @provider_name = (provider || RailsAiBuild.configuration.default_provider).to_sym
        @provider = Models::Registry.build(@provider_name)
        @model = model || RailsAiBuild.configuration.default_model
        @system_prompt = system_prompt || DEFAULT_SYSTEM_PROMPT
        @workspace = workspace || RailsAiBuild.configuration.workspace_path
        @tools = tools || Tools::Registry.build_all(workspace: @workspace)
        @messages = [Message.system(build_system_prompt)]
      end

      def build_system_prompt
        parts = []
        if RailsAiBuild.configuration.universal_builder && @system_prompt == DEFAULT_SYSTEM_PROMPT
          parts << Builder::Context.snapshot(workspace: @workspace)
        else
          parts << @system_prompt
          parts << Workspace::Paths.prompt_guidance(@workspace)
        end
        memory_context = begin
          Memory::Store.context_for(workspace: @workspace)
        rescue StandardError
          nil
        end
        parts << memory_context if memory_context
        parts.compact.join("\n\n")
      end

      def chat(user_message)
        @messages << Message.user(user_message)
        Runner.new(agent: self).run!
      end

      def messages
        @messages.map(&:to_h)
      end

      def add_message(message)
        @messages << message
      end

      def tool_definitions
        Tools::Registry.definitions
      end

      def execute_tool(tool_name, arguments)
        Tools::Registry.execute(tool_name, arguments, workspace: workspace)
      end
    end
  end
end
