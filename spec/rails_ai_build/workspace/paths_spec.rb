# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'fileutils'

RSpec.describe RailsAiBuild::Workspace::Paths do
  let(:workspace) { Pathname.new(Dir.mktmpdir('mailpilot')) }

  before do
    workspace.join('app/models').mkpath
    workspace.join('app/models/user.rb').write("class User; end\n")
  end

  after { FileUtils.rm_rf(workspace) }

  describe '.resolve' do
    it 'maps workspace alias to the app root' do
      expect(described_class.resolve(workspace, 'workspace')).to eq(workspace.expand_path)
      expect(described_class.resolve(workspace, '.')).to eq(workspace.expand_path)
      expect(described_class.resolve(workspace, nil)).to eq(workspace.expand_path)
    end

    it 'strips a mistaken workspace/ prefix' do
      resolved = described_class.resolve(workspace, 'workspace/app/models')
      expect(resolved).to eq(workspace.join('app/models').expand_path)
    end

    it 'strips the workspace basename prefix' do
      resolved = described_class.resolve(workspace, "#{workspace.basename}/app/models/user.rb")
      expect(resolved).to eq(workspace.join('app/models/user.rb').expand_path)
    end

    it 'resolves normal relative paths' do
      expect(described_class.resolve(workspace, 'app/models')).to eq(workspace.join('app/models').expand_path)
    end

    it 'rejects paths that escape the workspace' do
      expect {
        described_class.resolve(workspace, '../outside')
      }.to raise_error(RailsAiBuild::SecurityError)
    end
  end
end
