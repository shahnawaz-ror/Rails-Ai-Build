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
end
