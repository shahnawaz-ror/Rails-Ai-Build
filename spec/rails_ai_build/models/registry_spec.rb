# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsAiBuild::Models::Registry do
  before { described_class.reset! }

  describe ".register and .resolve" do
    it "registers and resolves providers" do
      klass = Class.new(RailsAiBuild::Models::BaseProvider)
      described_class.register(:test_provider, klass)

      entry = described_class.resolve(:test_provider)
      expect(entry[:class]).to eq(klass)
    end

    it "raises for unknown providers" do
      expect { described_class.resolve(:missing) }
        .to raise_error(RailsAiBuild::ConfigurationError, /Unknown provider/)
    end
  end

  describe ".register_defaults" do
    it "registers core providers" do
      described_class.register_defaults
      expect(described_class.registered_providers).to include(:openai, :anthropic)
    end
  end

  describe ".build" do
    it "instantiates provider with merged options" do
      klass = Class.new(RailsAiBuild::Models::BaseProvider) do
        attr_reader :options

        def initialize(name:, **options)
          super
          @options = options
        end
      end

      described_class.register(:builder, klass, temperature: 0.2)
      instance = described_class.build(:builder, temperature: 0.5, api_key: "x")

      expect(instance.options[:temperature]).to eq(0.5)
      expect(instance.options[:api_key]).to eq("x")
    end
  end
end
