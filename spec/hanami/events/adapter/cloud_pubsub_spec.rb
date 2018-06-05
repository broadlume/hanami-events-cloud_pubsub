# frozen_string_literal: true

require_relative './../../../../lib/hanami/events/adapter/cloud_pubsub'

module Hanami
  module Events
    RSpec.describe Adapter::CloudPubsub do
      let(:pubsub) { double }

      subject(:adapter) { described_class.new(pubsub: pubsub) }

      describe '#listen' do
        it 'does not listen by default' do
          expect(adapter.subscribe('test', id: 'test') {}).to eql(false)
          expect(adapter.subscribers).to be_empty
        end

        it 'can be explicitly turned on' do
          adapter.listen

          expect(adapter).to be_listening
        end
      end

      describe '#broadcast' do
        let(:topic) { double(publish_async: true) }
        let(:payload) { { test: true } }

        before do
          allow(adapter).to receive(:topic_for).and_return(topic)
        end

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
    end
  end
end
