# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsAiBuild::Marketplace::Registry do
  it "lists marketplace packs" do
    packs = described_class.all
    expect(packs.size).to be >= 4
    expect(packs.first).to have_key(:id)
  end

  it "finds a pack by id" do
    pack = described_class.find("crud-pro")
    expect(pack.name).to include("CRUD")
  end
end
