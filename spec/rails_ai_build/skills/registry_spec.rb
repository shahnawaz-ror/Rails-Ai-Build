# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsAiBuild::Skills::Registry do
  it "lists available skills" do
    skills = described_class.all
    expect(skills.map { |s| s[:name].to_s }).to include("crud", "auth", "api", "tests")
  end

  it "builds skill-specific prompts" do
    prompt = described_class.prompt_for("crud")
    expect(prompt).to include("CRUD")
    expect(prompt).to include("RESTful")
  end

  it "raises for unknown skills" do
    expect { described_class.prompt_for("unknown") }.to raise_error(RailsAiBuild::ConfigurationError)
  end
end
