# frozen_string_literal: true

require 'hanami/events/cloud_pubsub/middleware/request_id'

module Hanami
  module Events
    module CloudPubsub
      module Middleware
        RSpec.describe RequestId do
          let(:msg) { double(attributes: { 'request_id' => '123' }) }
          let(:middleware) { described_class.new }

          it 'clears when the middleware fails' do
            middleware.call(msg) { raise }
          rescue StandardError
            nil
          end

          it 'sets the request id for the job' do
            blk = double(call: true)

            middleware.call(msg) {
              blk.call
              expect(::RequestId.request_id).to eql('123')
            }
            expect(blk).to have_received(:call)
          end

          it 'clear the request id after the job' do
            blk = double(call: true)

            middleware.call(msg) {
              blk.call
            }
            expect(::RequestId.request_id).to eql(nil)
            expect(blk).to have_received(:call)
          end
        end
      end
    end
  end
end
