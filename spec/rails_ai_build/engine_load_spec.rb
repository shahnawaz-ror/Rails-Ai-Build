# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RailsAiBuild::Engine do
  it 'defines the Engine class when Rails is present' do
    expect(defined?(RailsAiBuild::Engine)).to eq('constant')
    expect(RailsAiBuild::Engine).to be < Rails::Engine
  end

  it 'exposes the setup rake task path' do
    rake_file = RailsAiBuild::Engine.root.join('lib/tasks/rails_ai_build.rake')
    expect(rake_file).to exist
    expect(File.read(rake_file)).to include('task setup')
  end
end
