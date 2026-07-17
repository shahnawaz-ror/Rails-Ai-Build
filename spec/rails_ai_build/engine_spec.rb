# frozen_string_literal: true

require "rails_helper"

RSpec.describe RailsAiBuild::Engine do
  it "isolates the RailsAiBuild namespace" do
    expect(described_class.isolated?).to be true
  end

  it "mounts at /rails_ai_build when auto_mount is enabled" do
    RailsAiBuild.configuration.auto_mount = true
    paths = Rails.application.routes.routes.map { |r| r.path.spec.to_s }
    expect(paths.any? { |p| p.include?("rails_ai_build") }).to be true
  end

  it "registers default model providers on boot" do
    expect(RailsAiBuild::Providers.registered_providers).to include(:openai)
  end

  it "orders heal_migrations after load_activation (no TSort cycle)" do
    names = described_class.initializers.map(&:name)
    heal = described_class.initializers.find { |i| i.name == "rails_ai_build.heal_migrations" }
    activation = described_class.initializers.find { |i| i.name == "rails_ai_build.load_activation" }

    expect(heal).to be_present
    expect(activation).to be_present
    expect(names.index("rails_ai_build.load_activation")).to be < names.index("rails_ai_build.heal_migrations")
    expect(heal.before).not_to eq(:load_config_initializers)
    expect(activation.after).to eq(:load_config_initializers)
  end
end
