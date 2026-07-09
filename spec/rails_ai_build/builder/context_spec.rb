# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'

RSpec.describe RailsAiBuild::Builder::Context do
  let(:workspace) { Pathname.new(Dir.mktmpdir) }

  before do
    workspace.join('Gemfile').write('gem "rails", "~> 8.1"')
    workspace.join('spec').mkpath
  end

  after { FileUtils.rm_rf(workspace) }

  it 'includes universal build capabilities in snapshot' do
    snapshot = described_class.snapshot(workspace: workspace)
    expect(snapshot).to include('build ANYTHING')
    expect(snapshot).to include('test_framework')
    expect(snapshot).to include('run_rails_check')
  end
end
