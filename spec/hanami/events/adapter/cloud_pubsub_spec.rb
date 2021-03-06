# frozen_string_literal: true

require_relative './../../../../lib/hanami/events/adapter/cloud_pubsub'
require 'dry/configurable/test_interface'

module Hanami
  module Events
    RSpec.describe Adapter::CloudPubsub do
      let(:pubsub) { double }
      let(:sub) do
        instance_double(Google::Cloud::Pubsub::Subscription,
                        listen: true,
                        retry_policy: nil,
                        dead_letter_topic: nil,
                        topic: double(name: 'projects/test/topics/some_namespace.test_event'))
      end
      let(:topic) do
        instance_double(Google::Cloud::Pubsub::Topic,
                        publish_async: true,
                        find_subscription: sub)
      end

      subject(:adapter) { described_class.new(pubsub: pubsub) }

      before do
        allow(adapter).to receive(:topic_for).and_return(topic)
      end

      before { CloudPubsub.enable_test_interface }
      after {  CloudPubsub.reset_config }

      describe '#broadcast' do
        let(:payload) { { test: true } }

        it 'publishes the event with uuid in the attributes' do
          expect(topic)
            .to receive(:publish_async)
            .with(anything, a_hash_including(id: be_a(String)))

          adapter.broadcast('test', payload)
        end

        it 'publishes the event with event_name in the attributes' do
          expect(topic)
            .to receive(:publish_async)
            .with(anything, a_hash_including(event_name: 'test'))

          adapter.broadcast('test', payload)
        end

        it 'publishes the event with the serialized payload' do
          expect(topic)
            .to receive(:publish_async)
            .with(payload.to_json, anything)

          adapter.broadcast('test', payload)
        end

        it 'broadcasts to the correct namespace' do
          CloudPubsub.configure do |config|
            config.namespace = :some_namespace
          end

          expect(adapter)
            .to receive(:topic_for)
            .with('some_namespace.test')
            .and_return(topic)

          expect(topic)
            .to receive(:publish_async)
            .with(payload.to_json, anything)

          adapter.broadcast('test', payload)
        end

        it 'publishes the event with message opts' do
          expect(topic)
            .to receive(:publish_async)
            .with(anything, include(ordering_key: 'foo'))

          adapter.broadcast('test', payload, ordering_key: 'foo')
        end
      end

      describe '#subscribe' do
        before do
          allow(sub).to receive(:deadline)
          allow(sub).to receive(:deadline=)
        end

        it 'passes the subscriber_opts to listen' do
          expect(sub).to receive(:listen).with(a_hash_including(deadline: 24))
          adapter.subscribe('some_namespace.test_event', id: 'test', deadline: 24)
        end

        it 'registers a listener for the correct namespace' do
          CloudPubsub.configure do |config|
            config.namespace = :some_namespace
          end

          expect(adapter)
            .to receive(:register_listener)
            .with('some_namespace.test_event', topic, 'some_namespace.test', anything, anything, anything)
            .and_call_original

          adapter.subscribe('test_event', id: 'test', deadline: 24)

          CloudPubsub.configure do |config|
            config.namespace = nil
          end
        end

        it 'allows for auto_ack to be configured' do
          expect(adapter)
            .to receive(:register_listener)
            .with(anything, topic, anything, false, anything, anything)
            .and_return(true)

          adapter.subscribe('test_event', id: 'test', deadline: 24, auto_ack: false)
        end
      end
    end
  end
end
