# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Trust — 20 real Rails applications (NVIDIA live)', :live do
  it 'proves file changes across 20 catalog app archetypes' do
    report = RailsAiBuild::Trust::Runner.run!(
      apps: RailsAiBuild::Trust::CatalogSample.apps(count: 20)
    )

    expect(report[:total]).to eq(20)
    expect(report[:passed]).to be >= 18,
                               "Trust run: #{report[:passed]}/#{report[:total]} passed. " \
                               "Failures: #{report[:apps].reject { |a| a['passed'] }.pluck('slug')}"

    expect(report[:pass_rate]).to be >= 0.9
    expect(File).to exist(RailsAiBuild::Trust::Report::LANDING_PATH)
  end
end
