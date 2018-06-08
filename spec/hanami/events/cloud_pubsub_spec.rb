# frozen_string_literal: true

require 'dry/configurable/test_interface'

RSpec.describe Hanami::Events::CloudPubsub do
  before { described_class.enable_test_interface }
  after { described_class.reset_config }

  it 'has a version number' do
    expect(Hanami::Events::CloudPubsub::VERSION).not_to be nil
  end

  describe '.subscriber' do
    it 'uses the same defaults a Google Cloud' do
      sub_config = described_class.config.subscriber.to_h

      expect(sub_config).to eql(streams: 4, threads: { push: 4, callback: 8 })
    end
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
