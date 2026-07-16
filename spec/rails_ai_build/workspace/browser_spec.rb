# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'

RSpec.describe RailsAiBuild::Workspace::Browser do
  let(:workspace) { Pathname.new(Dir.mktmpdir) }

  before do
    workspace.join('app/models').mkpath
    workspace.join('app/models/user.rb').write("class User\nend\n")
    workspace.join('Gemfile').write('gem "rails"')
  end

  after { FileUtils.rm_rf(workspace) }

  it 'returns a directory tree' do
    result = described_class.tree(workspace: workspace, depth: 3)
    expect(result[:entries]).not_to be_empty
    app = result[:entries].find { |e| e[:name] == 'app' }
    expect(app[:type]).to eq('directory')
  end

  it 'treats path workspace as the app root' do
    result = described_class.tree(workspace: workspace, path: 'workspace', depth: 2)
    expect(result[:error]).to be_nil
    expect(result[:entries].map { |e| e[:name] }).to include('app', 'Gemfile')
  end

  it 'reads files via ReadFileTool' do
    result = described_class.read_file(workspace: workspace, path: 'Gemfile')
    expect(result[:content]).to include('rails')
  end

  it 'blocks path traversal' do
    expect do
      described_class.read_file(workspace: workspace, path: '../../../etc/passwd')
    end.to raise_error(RailsAiBuild::SecurityError)
  end
end
