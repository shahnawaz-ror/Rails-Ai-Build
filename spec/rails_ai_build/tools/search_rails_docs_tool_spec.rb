# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'

RSpec.describe RailsAiBuild::Tools::SearchRailsDocsTool do
  let(:workspace) { Pathname.new(Dir.mktmpdir) }
  let(:tool) { described_class.new(workspace: workspace) }

  before do
    workspace.join('Gemfile').write('gem "rails", "~> 8.1"')
  end

  after { FileUtils.rm_rf(workspace) }

  it 'returns version-aware guide links' do
    result = tool.call('query' => 'routing')
    expect(result[:rails_version]).to eq('8.1')
    expect(result[:results].first[:url]).to include('guides.rubyonrails.org')
    expect(result[:results].first[:topic]).to eq('routing')
  end

  it 'requires a query' do
    result = tool.call('query' => '')
    expect(result[:error]).to eq('query is required')
  end
end
