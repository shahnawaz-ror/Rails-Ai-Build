# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RailsAiBuild::Models::NvidiaProvider do
  it 'uses NVIDIA NIM base URL' do
    provider = described_class.new(api_key: 'nvapi-test')
    expect(provider.instance_variable_get(:@base_url)).to eq('https://integrate.api.nvidia.com/v1')
  end

  it 'is registered in the provider registry' do
    RailsAiBuild::Models::Registry.register_defaults
    expect(RailsAiBuild::Models::Registry.registered_providers).to include(:nvidia)
  end
end
