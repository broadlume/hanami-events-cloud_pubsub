# frozen_string_literal: true

require 'hanami/events/cloud_pubsub/middleware/logging'

module Hanami
  module Events
    module CloudPubsub
      module Middleware
        RSpec.describe Logging do
          let(:test_logger) { double(info: true) }
          subject(:logging) { described_class.new(test_logger) }

          it 'logs the about of time the event took' do
            begin
              logging.call { raise }
            rescue StandardError
              nil
            end

            expect(test_logger)
              .to have_received(:info)
              .with(/Event took .* seconds to process/)
          end
        end
      end
    end
  end
end
