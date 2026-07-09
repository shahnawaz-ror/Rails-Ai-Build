# frozen_string_literal: true

require "simplecov" if ENV["COVERAGE"] == "true"

ENV["RAILS_ENV"] ||= "test"

require "tmpdir"
require "fileutils"
require "rails_ai_build"
require_relative "support/webmock"
require_relative "support/request_helpers"
