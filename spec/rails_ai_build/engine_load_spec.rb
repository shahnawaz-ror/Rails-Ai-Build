# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RailsAiBuild::Engine do
  it 'is a Rails::Engine' do
    expect(described_class).to be < Rails::Engine
  end

  it 'exposes the setup rake task path' do
    rake_file = described_class.root.join('lib/tasks/rails_ai_build.rake')
    expect(rake_file).to exist
    expect(File.read(rake_file)).to include('task setup')
  end
end
