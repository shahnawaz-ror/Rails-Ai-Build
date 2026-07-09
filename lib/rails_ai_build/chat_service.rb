# frozen_string_literal: true

module RailsAiBuild
  # High-level facade for programmatic agent usage without touching ActiveRecord.
  class ChatService
    def self.ask(prompt, provider: nil, model: nil, system_prompt: nil, workspace: nil)
      if system_prompt
        agent = Agents::Agent.new(
          provider: provider,
          model: model,
          system_prompt: system_prompt,
          workspace: workspace
        )
        agent.chat(prompt)
      else
        Ai::Driver.run(prompt, provider: provider, model: model, workspace: workspace).to_h
      end
    end

    def self.run(prompt, **options)
      Ai::Driver.run(prompt, **options)
    end

    def self.build(task, **options)
      Builder::Universal.build(task, **options)
    end

    def self.fix(issue, **options)
      Builder::Universal.fix(issue, **options)
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
