# frozen_string_literal: true

require_relative './../../../../lib/hanami/events/adapter/cloud_pubsub'

module Hanami
  module Events
    RSpec.describe Adapter::CloudPubsub do
      let(:pubsub) { double }
      let(:sub) { instance_double(Google::Cloud::Pubsub::Subscription, listen: true) }
      let(:topic) do
        instance_double(Google::Cloud::Pubsub::Topic,
                        publish_async: true,
                        create_subscription: sub)
      end

      subject(:adapter) { described_class.new(pubsub: pubsub) }

      before do
        allow(adapter).to receive(:topic_for).and_return(topic)
      end

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
      end

      describe '#subscribe' do
        it 'passes the subscriber_opts to listen' do
          expect(sub).to receive(:listen).with(a_hash_including(deadline: 24))
          adapter.subscribe('test_event', id: 'test', deadline: 24)
        end
      end
    end
  end
end
