# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RailsAiBuild::Trust::AppSandbox do
  it 'builds manifest with 20 preview URLs' do
    manifest = described_class.manifest
    expect(manifest.size).to eq(20)
    expect(manifest.first[:preview_url]).to include('/apps/')
    expect(manifest.first[:api_run_url]).to end_with('/run')
  end
end
