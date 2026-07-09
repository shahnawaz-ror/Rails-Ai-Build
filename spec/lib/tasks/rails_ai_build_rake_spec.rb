# frozen_string_literal: true

require 'rails_helper'
require 'rake'

RSpec.describe 'rails_ai_build rake tasks' do
  before(:all) do
    Rake.application = Rake::Application.new
    load RailsAiBuild::Engine.root.join('lib/tasks/rails_ai_build.rake')
    Rake::Task.define_task(:environment)
  end

  before do
    Rake::Task.tasks.each(&:reenable)
    RailsAiBuild.reset_configuration!
    RailsAiBuild.configure { |c| c.api_keys[:openai] = 'sk-test' }
  end

  describe 'rails_ai_build:doctor' do
    it 'prints diagnostics' do
      expect { Rake::Task['rails_ai_build:doctor'].invoke }.to output(/Doctor/).to_stdout
    end
  end

  describe 'rails_ai_build:help' do
    it 'lists help topics' do
      expect { Rake::Task['rails_ai_build:help'].invoke }.to output(/getting-started/).to_stdout
    end

    it 'shows a specific topic' do
      expect { Rake::Task['rails_ai_build:help'].invoke('upgrade') }.to output(/Upgrade/).to_stdout
    end
  end

  describe 'rails_ai_build:upgrade' do
    it 'prints upgrade guide' do
      expect { Rake::Task['rails_ai_build:upgrade'].invoke }.to output(/rails_ai_build/).to_stdout
    end
  end

  describe 'rails_ai_build:pending' do
    it 'reports no pending changes' do
      expect { Rake::Task['rails_ai_build:pending'].invoke }.to output(/No pending/).to_stdout
    end
  end

  describe 'rails_ai_build:stats' do
    it 'prints analytics JSON' do
      expect { Rake::Task['rails_ai_build:stats'].invoke }.to output(/"version"/).to_stdout
    end
  end
end
