# frozen_string_literal: true

require 'hanami/events/cloud_pubsub/middleware/auto_acknowledge'

module Hanami
  module Events
    module CloudPubsub
      module Middleware
        RSpec.describe AutoAcknowledge do
          let(:msg) { double(acknowledge!: true, reject!: true, message_id: 123) }

          subject(:middleware) do
            described_class.new(logger: test_logger)
          end

          it 'acknowledges the message on success' do
            expect(msg).to receive(:acknowledge!)
            expect(test_logger).to receive(:debug).with(/was acknowledged/)

            middleware.call(msg) { true }
          end

          it 'acknowledges the message on error' do
            expect(msg).to receive(:acknowledge!)
            expect(test_logger).to receive(:debug).with(/was acknowledged/)

            begin
              middleware.call(msg) { raise }
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
