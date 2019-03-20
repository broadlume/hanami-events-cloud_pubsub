# frozen_string_literal: true

require 'hanami/events/cloud_pubsub/middleware/auto_retry'

module Hanami
  module Events
    module CloudPubsub
      module Middleware
        RSpec.describe AutoRetry do
          let(:msg) do
            instance_double(Google::Cloud::Pubsub::ReceivedMessage,
                            modify_ack_deadline!: true,
                            acknowledge!: true,
                            reject!: true,
                            message_id: 123)
          end

          subject(:middleware) do
            described_class.new(logger: test_logger)
          end

          it 'acknowledges the message on success' do
            expect(msg).to receive(:acknowledge!)
            expect(test_logger).to receive(:debug).with(/was acknowledged/)

            middleware.call(msg) { true }
          end

          it 'modifies the ack deadline on failure' do
            expect(msg).to receive(:modify_ack_deadline!)
            expect(test_logger)
              .to receive(:debug)
              .with(/failed, added 60 seconds of delay to ack deadline/)

            begin
              middleware.call(msg) { raise }
            rescue StandardError
              nil
            end
          end

          it 'uses a backoff formula if attempts are given' do
            expect(msg).to receive(:modify_ack_deadline!)
            expect(test_logger)
              .to receive(:debug)
              .with(/failed, added \d\d\d seconds of delay to ack deadline/)

            expect(test_logger)
              .to receive(:debug)
              .with(/failed, added 600 seconds of delay to ack deadline/)

            begin
              middleware.call(msg, attempts: 4) { raise }
            rescue StandardError
              nil
            end

            begin
              middleware.call(msg, attempts: 20) { raise }
            rescue StandardError
              nil
            end
          end

          it 'acknowledges the message when max attempts are reached' do
            expect(msg).to receive(:acknowledge!)

            begin
              middleware.call(msg, attempts: 1200) { raise }
            rescue StandardError
              nil
            end
          end

          it 'does not acknowledge the message on outside termination' do
            expect(msg).not_to receive(:acknowledge!)

            begin
              # Does not get rescued from StandardError
              middleware.call(msg) { raise NotImplementedError }
            rescue NotImplementedError
              nil
            end
          end
        end
      end
    end
  end
end
