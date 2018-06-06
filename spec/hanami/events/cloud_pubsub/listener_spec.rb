# frozen_string_literal: true

require 'hanami/events/cloud_pubsub/listener'

RSpec.describe Hanami::Events::CloudPubsub::Listener do
  let(:topic_name) { 'test-' + SecureRandom.hex(12) }
  let(:subscriber_id) { 'test-' + SecureRandom.hex(12) }
  let(:topic) { pubsub.create_topic(topic_name) }
  let(:pubsub) { Google::Cloud::Pubsub.new }
  let(:logger) { test_logger }

  before(:all) do
    spawn 'docker run --rm --name listener_spec ' \
          '-p 8086:8085 adhawk/google-pubsub-emulator',
          out: log_file, err: log_file
  end

  after(:all) do
    system 'docker stop listener_spec',
           out: log_file, err: log_file
  end

  subject(:listener) do
    described_class.new(topic: topic,
                        logger: logger,
                        handler: handler,
                        event_name: topic_name,
                        subscriber_id: subscriber_id)
  end

  describe '#start' do
    context 'success' do
      let(:handler) { double(call: true) }

      it 'enables the listener to receive messages' do
        expect(handler).to receive(:call)

        listener.register
        listener.start
        topic.publish 'hello'
        sleep 1

        listener.shutdown
      end
    end

    context 'failure' do
      let(:handler) { proc { raise 'Oh no' } }

      it 'logs errors' do
        listener.register
        listener.start
        expect(logger).to receive(:error).with(/Oh no/)
        topic.publish 'hello'
        sleep 2

        listener.shutdown
      end
    end
  end
end
