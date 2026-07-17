# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RailsAiBuild::Integrations::Git do
  let(:workspace) { Pathname.new(Dir.mktmpdir) }

  before do
    RailsAiBuild.reset_configuration!
    RailsAiBuild.configuration.workspace_root = workspace
    init_git_repo(workspace)
  end

  after { FileUtils.rm_rf(workspace) }

  describe '.summary' do
    it 'returns branch and status' do
      summary = described_class.summary
      expect(summary[:branch]).to be_present
      expect(summary[:recent_commits]).not_to be_empty
    end
  end

  describe '.changed_files' do
    it 'lists modified files' do
      File.write(workspace.join('dirty.txt'), 'change')
      expect(described_class.changed_files).to include('dirty.txt')
    end
  end

  describe '.create_branch' do
    it 'creates a branch ref without checking out the host tree' do
      before = described_class.current_branch
      described_class.create_branch('ai/task-test1234')
      expect(described_class.current_branch).to eq(before)
      branches = Dir.chdir(workspace) { `git branch --list ai/task-test1234` }
      expect(branches).to include('ai/task-test1234')
    end
  end

  describe '.commit' do
    it 'requires team plan' do
      expect { described_class.commit(message: 'test') }
        .to raise_error(RailsAiBuild::ConfigurationError, /plan/)
    end

    it 'commits when plan allows' do
      RailsAiBuild.configuration.plan = :team
      File.write(workspace.join('feature.txt'), 'x')
      result = described_class.commit(message: 'AI commit')
      expect(result[:success]).to be(true)
    end
  end
end
