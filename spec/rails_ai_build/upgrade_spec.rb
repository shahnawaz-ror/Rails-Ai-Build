# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RailsAiBuild::Upgrade do
  let(:workspace) { Pathname.new(Dir.mktmpdir) }

  after { FileUtils.rm_rf(workspace) }

  describe '.status' do
    it 'detects when upgrade is needed' do
      write_initializer('1.3.0')
      info = described_class.status(workspace: workspace)
      expect(info[:needs_upgrade]).to be(true)
      expect(info[:steps]).not_to be_empty
    end

    it 'reports current when versions match' do
      write_initializer(RailsAiBuild::VERSION)
      info = described_class.status(workspace: workspace)
      expect(info[:needs_upgrade]).to be(false)
    end
  end

  describe '.chat_guide' do
    it 'returns install steps when not stamped' do
      guide = described_class.chat_guide(nil)
      expect(guide).to include('rails generate rails_ai_build:install')
    end

    it 'returns upgrade steps for older versions' do
      write_initializer('1.3.0')
      guide = described_class.chat_guide('1.3.0')
      expect(guide).to include('bundle update rails_ai_build')
    end
  end

  describe '.stamp_initializer' do
    it 'adds version marker to initializer' do
      path = workspace.join('config/initializers/rails_ai_build.rb')
      FileUtils.mkdir_p(path.dirname)
      File.write(path, "# frozen_string_literal: true\n\nRailsAiBuild.configure {}\n")
      described_class.stamp_initializer(path, version: '9.9.9')
      expect(path.read).to include('rails_ai_build_version: 9.9.9')
    end
  end

  def write_initializer(version)
    path = workspace.join('config/initializers/rails_ai_build.rb')
    FileUtils.mkdir_p(path.dirname)
    File.write(path, "# frozen_string_literal: true\n\n# rails_ai_build_version: #{version}\n")
  end
end
