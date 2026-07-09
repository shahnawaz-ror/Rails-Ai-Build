# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'

RSpec.describe RailsAiBuild::Tools::ApplicationInfoTool do
  let(:workspace) { Pathname.new(Dir.mktmpdir) }
  let(:tool) { described_class.new(workspace: workspace) }

  before do
    workspace.join('Gemfile').write(<<~GEMFILE)
      source "https://rubygems.org"
      gem "rails", "~> 8.1"
      gem "rspec-rails"
      gem "sidekiq"
    GEMFILE
    workspace.join('spec').mkpath
  end

  after { FileUtils.rm_rf(workspace) }

  it 'returns application metadata from workspace files' do
    result = tool.call({})
    expect(result[:rails_version]).to eq('8.1')
    expect(result[:conventions][:test_framework]).to eq(:rspec)
    expect(result[:conventions][:job_backend]).to eq(:sidekiq)
    expect(result[:recommendations]).to include('Use RSpec skill and factories')
  end
end
