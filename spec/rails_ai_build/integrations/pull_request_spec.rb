# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RailsAiBuild::Integrations::PullRequest do
  let(:workspace) { Pathname.new(Dir.mktmpdir) }

  before do
    RailsAiBuild.reset_configuration!
    RailsAiBuild.configure do |c|
      c.workspace_root = workspace
      c.plan = :team
    end
    init_git_repo(workspace)
    system("git -C #{workspace} remote add origin git@github.com:acme/app.git", exception: true)
  end

  after { FileUtils.rm_rf(workspace) }

  describe '.create' do
    it 'creates branch and returns github PR URL' do
      File.write(workspace.join('change.rb'), '1')
      result = described_class.create(title: 'AI changes')
      expect(result[:branch]).to start_with('ai/rails-ai-build-')
      expect(result[:pr_url]).to include('github.com/acme/app')
    end

    it 'requires team plan' do
      RailsAiBuild.configuration.plan = :free
      expect { described_class.create(title: 'x') }
        .to raise_error(RailsAiBuild::ConfigurationError)
    end
  end
end
