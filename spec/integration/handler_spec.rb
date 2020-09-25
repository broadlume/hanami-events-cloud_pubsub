# frozen_string_literal: true

require 'request_id'
require 'hanami/events/adapter/cloud_pubsub'

module Hanami
  module Events
    RSpec.describe 'Integration' do
      let(:topic_name) { "test-#{SecureRandom.hex(12)}" }
      let(:subscriber_id) { "test-#{SecureRandom.hex(12)}" }
      let(:topic) { pubsub.find_topic(topic_name) }
      let(:pubsub) { Google::Cloud::Pubsub.new }
      let(:logger) { test_logger }

      before(:all) do
        spawn 'docker run --rm --name integration_spec ' \
          '-p 8086:8085 adhawk/google-pubsub-emulator',
              out: log_file, err: log_file
      end

      after(:all) do
        system 'docker stop integration_spec',
               out: log_file, err: log_file
      end

      subject(:adapter) do
        Adapter::CloudPubsub.new(pubsub: pubsub, logger: logger)
      end

      around do |ex|
        topic = pubsub.create_topic(topic_name)
        subscription = topic.create_subscription(subscriber_id)
        ex.run
      ensure
        topic&.delete
        subscription&.delete
      end

      context 'when a handler has an arity of two' do
        it 'calls the handler with the payload and the raw pubsub message' do
          payload = { foo: :bar }
          message = respond_to(:message_id, :subscription)
          handler_double = double(call: true)

          adapter.subscribe(topic_name, id: subscriber_id) do |p, m|
            handler_double.call(p, m)
          end

          start_listeners do
            adapter.broadcast topic_name, payload
            sleep 1
          end

          expect(handler_double).to have_received(:call).with(be_a(Hash), message)
        end
      end

      context 'serialization' do
        it 'serializes the payload as json, and parses with string keys' do
          payload = { foo: :bar }
          handler_double = double(call: true)

          adapter.subscribe(topic_name, id: subscriber_id) do |p|
            handler_double.call(p)
          end

          start_listeners do
            adapter.broadcast topic_name, payload
            sleep 1
          end

          expect(handler_double).to have_received(:call).with('foo' => 'bar')
        end
      end

      context 'request id' do
        it 'broadcasts with the request id' do
          payload = { foo: :bar }
          handler_double = double(call: true)

          adapter.subscribe(topic_name, id: subscriber_id) do |p, m|
            handler_double.call(p, m.message.attributes)
          end

          start_listeners do
            adapter.broadcast topic_name, payload
            sleep 1
          end

          expect(handler_double)
            .to have_received(:call)
            .with(anything, include({ 'request_id' => match(/^\h{8}/) }))
        end
      end

      context 'when the subscription name does not match requested subscription name' do
        it 'calls the handler with the payload and the raw pubsub message' do
          handler_double = double(call: true)
          updated_topic_name = "#{topic_name}.updated"
          pubsub.create_topic(updated_topic_name)

          adapter.subscribe(topic_name, id: subscriber_id) do |p, m|
            handler_double.call(p, m)
          end

          expect do
            adapter.subscribe(updated_topic_name, id: subscriber_id) {}
          end.to raise_error CloudPubsub::Errors::SubscriptionTopicNameMismatch
        end
      end

      context 'when using auto_retry' do
        let(:dead_letter_topic_name) { "test-dead-letter-#{SecureRandom.hex(5)}" }

        before do
          config = double(
            enabled: true,
            max_attempts: 5,
            dead_letter_topic_name: dead_letter_topic_name,
            minimum_backoff: 1,
            maximum_backoff: 2
          )

          allow(CloudPubsub.config).to receive(:auto_retry).and_return(config)
        end

        around do |ex|
          topic = pubsub.create_topic(dead_letter_topic_name)
          ex.run
        ensure
          topic&.delete
        end

        it 'retries the failed blocks' do
          skip unless ENV.key?('REAL_PUBSUB')

          payload = { foo: :bar }
          handler_double = double(call: true)
          count = 0

          adapter.subscribe(topic_name, id: subscriber_id) do |p, m|
            count += 1
            handler_double.call(p, m)
            raise 'oh no!'
          end

          start_listeners do
            adapter.broadcast topic_name, payload

            Timeout.timeout(30) do
              loop { break if count == 5 }
            end
          end

          expect(handler_double).to have_received(:call).exactly(5).times
        end
      end

      def start_listeners
        adapter.listeners.each(&:start)
        yield
      ensure
        adapter.listeners.each(&:stop)
      end
    end
  end
end
