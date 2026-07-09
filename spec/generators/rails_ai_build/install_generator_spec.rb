# frozen_string_literal: true

require 'rails_helper'
require 'rails/generators/testing/behavior'
require 'rails/generators/testing/setup_and_teardown'
require 'rails/generators/testing/assertions'
require 'generators/rails_ai_build/install/install_generator'

RSpec.describe RailsAiBuild::Generators::InstallGenerator, type: :generator do
  include Rails::Generators::Testing::Behavior
  include Rails::Generators::Testing::SetupAndTeardown
  include Rails::Generators::Testing::Assertions

  tests described_class
  destination File.join(Dir.tmpdir, 'rails_ai_build_install_generator')

  before { prepare_destination }

  it 'creates migration and initializer with version stamp' do
    run_generator
    assert_file 'config/initializers/rails_ai_build.rb', /rails_ai_build_version:/
    migrate_files = Dir.glob(File.join(destination_root, 'db/migrate/**/*rails_ai_build*'))
    expect(migrate_files).not_to be_empty
  end
end
