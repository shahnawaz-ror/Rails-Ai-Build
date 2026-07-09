# frozen_string_literal: true

require 'rails_helper'
require 'fileutils'

RSpec.configure do |config|
  config.include FileUtils, type: :generator
end
