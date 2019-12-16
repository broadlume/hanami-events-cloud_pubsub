# frozen_string_literal: true

require 'hanami/events/cloud_pubsub/listener'
require 'dry/configurable/test_interface'

module Hanami
  module Events
    module CloudPubsub
      RSpec.describe Listener do
        let(:topic_name) { 'test-' + SecureRandom.hex(12) }
        let(:subscriber_id) { 'test-' + SecureRandom.hex(12) }
        let(:topic) { pubsub.find_topic(topic_name) }
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

        around do |ex|
          begin
            topic = pubsub.create_topic(topic_name)
            subscription = topic.create_subscription(subscriber_id)
            ex.run
          ensure
            topic&.delete
            subscription&.delete
          end
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

            it 'allows for configurable concurrency' do
              listener = described_class.new(
                topic: topic,
                logger: logger,
                handler: proc { sleep 0.1 },
                event_name: topic_name,
                subscriber_id: subscriber_id,
                subscriber_opts: { threads: { callback: 1, push: 1 }, streams: 1 }
              )

              20.times { topic.publish 'hello' }

              expect do
                listener.register
                listener.start
                sleep 2
              end.to change { Thread.list.count }.by(6)

              listener.shutdown
            end
          end

          context 'failure' do
            let(:handler) { proc { raise StandardError, 'Oh no' } }
            let(:error_handler) { double(:call) }

            before do
              CloudPubsub.enable_test_interface

              CloudPubsub.configure do |config|
                config.error_handlers = [error_handler]
              end
            end

            after { CloudPubsub.reset_config }

            it 'calls the CloudPubsub.error_handlers' do
              listener.register
              listener.start

              expect(error_handler)
                .to receive(:call)
                .with(
                  StandardError,
                  an_instance_of(Google::Cloud::Pubsub::ReceivedMessage)
                )

              topic.publish 'hello'
              sleep 1
              listener.shutdown
            end
          end
        end
      end
    end
  end
end
