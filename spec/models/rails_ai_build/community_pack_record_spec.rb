# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RailsAiBuild::CommunityPackRecord do
  it 'generates slug from name' do
    pack = build_community_pack(name: 'Rails CRUD Pack')
    expect(pack.slug).to eq('rails-crud-pack')
  end

  describe 'scopes' do
    it 'separates approved and pending packs' do
      build_community_pack(name: 'Pending Pack')
      build_community_pack(name: 'Live Pack', approved: true)
      expect(described_class.pending.count).to eq(1)
      expect(described_class.approved.count).to eq(1)
    end
  end

  describe '#to_marketplace_entry' do
    it 'exports marketplace metadata' do
      pack = build_community_pack(name: 'API Pack', approved: true, price: 0)
      entry = pack.to_marketplace_entry
      expect(entry[:id]).to eq('api-pack')
      expect(entry[:community]).to be(true)
    end
  end
end
