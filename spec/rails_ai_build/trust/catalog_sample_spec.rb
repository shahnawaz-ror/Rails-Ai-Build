# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RailsAiBuild::Trust::CatalogSample do
  it 'selects 20 diverse apps from the catalog' do
    apps = described_class.apps(count: 20)
    expect(apps.size).to eq(20)
    expect(apps.pluck('slug').uniq.size).to eq(20)
    archetypes = apps.pluck('archetype').tally
    expect(archetypes.keys).to include('full_stack', 'engine')
  end
end
