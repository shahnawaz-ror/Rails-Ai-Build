# frozen_string_literal: true

module RailsAiBuild
  # High-level facade for programmatic agent usage without touching ActiveRecord.
  class ChatService
    def self.ask(prompt, provider: nil, model: nil, system_prompt: nil, workspace: nil)
      agent = Agents::Agent.new(
        provider: provider,
        model: model,
        system_prompt: system_prompt,
        workspace: workspace
      )
      agent.chat(prompt)
    end

    def self.create_agent(**options)
      Agents::Agent.new(**options)
    end

    def self.register_custom_provider(name, **options)
      RailsAiBuild::Models::Registry.register(
        name,
        Models::CustomProvider,
        options
      )
    end
  end
end
