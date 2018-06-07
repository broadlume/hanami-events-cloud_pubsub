# frozen_string_literal: true

require 'dry/configurable/test_interface'

RSpec.describe Hanami::Events::CloudPubsub do
  before { described_class.enable_test_interface }
  after { described_class.reset_config }

  it 'has a version number' do
    expect(Hanami::Events::CloudPubsub::VERSION).not_to be nil
  end

  describe '.logger' do
    it 'allows for a logger to be configured' do
      logger = :foo

      described_class.configure do |config|
        config.logger = logger
      end

      expect(described_class.logger).to eql(logger)
    end

    it 'defaults to a basic logger' do
      expect(described_class.logger).to respond_to(
        :info,
        :warn,
        :debug,
        :error
      )
    end
  end
end
