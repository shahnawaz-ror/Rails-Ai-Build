# frozen_string_literal: true

module RailsAiBuild
  module Marketplace
    Pack = Struct.new(:id, :name, :description, :author, :price, :skill, :prompt, keyword_init: true)

    CATALOG = [
      Pack.new(
        id: "crud-pro",
        name: "CRUD in 60 Seconds",
        description: "Full Rails CRUD with Hotwire, RSpec, and FactoryBot",
        author: "Rails AI Build",
        price: 9,
        skill: :crud,
        prompt: Skills::CrudSkill.prompt
      ),
      Pack.new(
        id: "rspec-writer",
        name: "RSpec Test Writer",
        description: "Comprehensive test coverage for existing code",
        author: "Rails AI Build",
        price: 9,
        skill: :tests,
        prompt: Skills::TestsSkill.prompt
      ),
      Pack.new(
        id: "security-audit",
        name: "Security Audit Agent",
        description: "Brakeman-style security review with fixes",
        author: "Rails AI Build",
        price: 49,
        skill: :refactor,
        prompt: <<~PROMPT
          You are a Rails security auditor. Check for:
          - SQL injection, XSS, CSRF vulnerabilities
          - Mass assignment issues in strong params
          - Authentication/authorization gaps
          - Insecure dependencies in Gemfile
          Run brakeman if available. Propose fixes with minimal changes.
        PROMPT
      ),
      Pack.new(
        id: "hotwire-scaffold",
        name: "Hotwire Scaffold Pro",
        description: "Turbo Frames, Streams, and Stimulus controllers",
        author: "Rails AI Build",
        price: 15,
        skill: :crud,
        prompt: <<~PROMPT
          Scaffold with Hotwire best practices:
          - Turbo Frames for partial page updates
          - Turbo Streams for real-time DOM changes
          - Stimulus controllers for JavaScript behavior
          - No unnecessary full page reloads
        PROMPT
      )
    ].freeze

    class Registry
      class << self
        def all
          CATALOG.map(&:to_h)
        end

        def find(id)
          CATALOG.find { |p| p.id == id.to_s }
        end

        def install(id, agent_options: {})
          pack = find(id)
          raise ConfigurationError, "Pack not found: #{id}" unless pack

          Agents::Agent.new(
            system_prompt: pack.prompt,
            **agent_options
          )
        end
      end
    end
  end
end
