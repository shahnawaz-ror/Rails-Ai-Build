# frozen_string_literal: true

module RailsAiBuild
  module Ai
    # Assembles context before every model call — automatic like Cursor.
    class ContextEngine
      Snapshot = Struct.new(:rails, :conventions, :recommendations, :memory, :timestamp, keyword_init: true) do
        def to_prompt_section
          <<~CTX
            ## Live application context (#{timestamp&.iso8601})
            - Rails: #{rails}
            - Conventions: #{conventions}
            - Guidance: #{recommendations}
            #{"- Memory: #{memory}" if memory && !memory.to_s.empty?}
          CTX
        end

        def to_h
          {
            rails: rails,
            conventions: conventions,
            recommendations: recommendations,
            memory: memory,
            timestamp: timestamp&.iso8601
          }
        end
      end

      class << self
        def snapshot(workspace: nil)
          workspace ||= RailsAiBuild.configuration.workspace_path
          profile = Compatibility::ConventionDetector.detect(workspace: workspace)
          recs = Compatibility::ConventionDetector.recommendations(profile)
          rails = Tools::RailsContext.infer_rails_version(workspace)
          memory = begin
            Memory::Store.context_for(workspace: workspace)
          rescue StandardError
            nil
          end

          Snapshot.new(
            rails: rails,
            conventions: profile.to_h,
            recommendations: recs,
            memory: memory,
            timestamp: Time.zone.now
          )
        end

        def system_prompt(workspace: nil, session: nil, skill: nil)
          parts = []
          parts << Builder::Context::UNIVERSAL_PROMPT if RailsAiBuild.configuration.universal_builder
          parts << Skills::Registry.prompt_for(skill) if skill
          parts << snapshot(workspace: workspace).to_prompt_section
          parts << "## Conversation\nContinue this thread coherently." if session&.messages&.any?
          parts.compact.join("\n\n")
        end
      end
    end
  end
end
