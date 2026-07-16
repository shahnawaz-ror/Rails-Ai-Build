# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsAiBuild::Generators::Catalog do
  it "loads declarative entries and allowlists generators" do
    expect(described_class.entries).not_to be_empty
    expect(described_class.allowlisted_generators).to include("scaffold", "model", "migration")
    expect(described_class.find("scaffold")).to include("generator" => "scaffold")
  end
end
