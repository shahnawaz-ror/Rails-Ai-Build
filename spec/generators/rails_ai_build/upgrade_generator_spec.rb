# frozen_string_literal: true

require 'rails_helper'
require 'rails/generators/testing/behavior'
require 'rails/generators/testing/setup_and_teardown'
require 'generators/rails_ai_build/upgrade/upgrade_generator'

RSpec.describe RailsAiBuild::Generators::UpgradeGenerator, type: :generator do
  include Rails::Generators::Testing::Behavior
  include Rails::Generators::Testing::SetupAndTeardown

  tests described_class
  destination File.join(Dir.tmpdir, 'rails_ai_build_upgrade_generator')

  before do
    prepare_destination
    FileUtils.mkdir_p(File.join(destination_root, 'config/initializers'))
    File.write(
      File.join(destination_root, 'config/initializers/rails_ai_build.rb'),
      "# frozen_string_literal: true\n\n# rails_ai_build_version: 1.3.0\nRailsAiBuild.configure {}\n"
    )
  end

  it 'stamps initializer with current version' do
    run_generator
    content = File.read(File.join(destination_root, 'config/initializers/rails_ai_build.rb'))
    expect(content).to include("rails_ai_build_version: #{RailsAiBuild::VERSION}")
  end
end
