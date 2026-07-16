# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'

RSpec.describe RailsAiBuild::Ai::ContextEngine do
  let(:workspace) { Pathname.new(Dir.mktmpdir) }

  before do
    workspace.join('Gemfile').write('gem "rails", "~> 8.1"')
    workspace.join('spec').mkpath
  end

  after { FileUtils.rm_rf(workspace) }

  it 'builds a live context snapshot' do
    snap = described_class.snapshot(workspace: workspace)
    expect(snap.rails).to eq('8.1')
    expect(snap.conventions[:test_framework]).to eq(:rspec)
  end

  it 'includes universal prompt in system prompt' do
    prompt = described_class.system_prompt(workspace: workspace)
    expect(prompt).to include('build ANYTHING')
    expect(prompt).to include('Live application context')
    expect(prompt).to include('relative to the app root')
    expect(prompt).to include('not a directory inside the app')
  end
end
