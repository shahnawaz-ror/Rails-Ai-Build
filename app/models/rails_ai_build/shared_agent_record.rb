# frozen_string_literal: true

module RailsAiBuild
  class SharedAgentRecord < ApplicationRecord
    self.table_name = "rails_ai_build_shared_agents"

    validates :name, presence: true, uniqueness: true
    validates :system_prompt, presence: true

    scope :published, -> { where(published: true) }

    def to_agent
      Agents::Agent.new(
        name: name,
        provider: provider || "openai",
        model: model_name,
        system_prompt: system_prompt
      )
    end
  end
end
