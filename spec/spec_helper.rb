# frozen_string_literal: true

ENV['PUBSUB_EMULATOR_HOST'] ||= 'localhost:8085'

require 'bundler/setup'
require 'hanami/events/cloud_pubsub'

Google::Cloud::Pubsub.configure do |config|
  config.project_id = 'communique-spec'
end

module SpecLogging
  def log_path
    @log_path ||= File.join(
      Gem::Specification.find_by_name('hanami-events-cloud_pubsub').gem_dir,
      'log/test.log'
    )
  end

  def log_file
    @log_file ||= File.open(log_path, File::WRONLY | File::APPEND)
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
