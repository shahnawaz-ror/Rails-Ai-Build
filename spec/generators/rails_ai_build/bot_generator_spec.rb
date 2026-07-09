# frozen_string_literal: true

require 'rails_helper'
require 'rails/generators/testing/behavior'
require 'rails/generators/testing/setup_and_teardown'
require 'rails/generators/testing/assertions'
require 'generators/rails_ai_build/bot/bot_generator'

RSpec.describe RailsAiBuild::Generators::BotGenerator, type: :generator do
  include Rails::Generators::Testing::Behavior
  include Rails::Generators::Testing::SetupAndTeardown
  include Rails::Generators::Testing::Assertions

  tests described_class
  destination File.join(Dir.tmpdir, 'rails_ai_build_bot_generator')

  before { prepare_destination }

  it 'copies slack bot initializer by default' do
    run_generator
    assert_file 'config/initializers/rails_ai_build_slack.rb'
  end

  it 'copies discord initializer when platform is discord' do
    run_generator %w[--platform=discord]
    assert_file 'config/initializers/rails_ai_build_discord.rb'
  end
end
