# frozen_string_literal: true

ENV['PUBSUB_EMULATOR_HOST'] ||= 'localhost:8086' unless ENV['REAL_PUBSUB']

if ENV['COVERAGE'] == 'true'
  require 'simplecov'
  SimpleCov.start
end

require 'bundler/setup'
require 'pry'
require 'yabeda/prometheus/mmap'
require 'hanami/events/cloud_pubsub'

Google::Cloud::Pubsub.configure do |config|
  config.project_id = ENV['GOOGLE_CLOUD_PROJECT'] || 'adhawk-franchises-development'
end

module SpecLogging
  def log_path
    @log_path ||= File.join(
      Gem::Specification.find_by_name('hanami-events-cloud_pubsub').gem_dir,
      'log/test.log'
    )
  end

  def log_file
    @log_file ||= File.open(log_path, 'a+')
  end

  def test_logger
    @test_logger ||= Logger.new(log_file)
  end
end

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.include SpecLogging

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
