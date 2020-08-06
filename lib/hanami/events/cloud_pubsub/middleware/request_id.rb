# frozen_string_literal: true

begin
  require 'request_id'
rescue LoadError
  abort 'Please add "request_id" to your Gemfile to use this middleware'
end

module Hanami
  module Events
    module CloudPubsub
      module Middleware
        # Middleware used for logging useful information about an event
        class RequestId
          def call(msg, **opts)
            setup_request_id(msg)
            yield(**opts)
          ensure
            clear_request_id(msg)
          end

          private

          def setup_request_id(msg)
            id = msg.attributes['request_id'] || msg.attributes[:request_id]

            ::RequestId.request_id = id || SecureRandom.uuid
          rescue StandardError => e
            warn "Could not set request_id (#{e.message})"
          end

          def clear_request_id(_msg)
            ::RequestId.request_id = nil
          rescue StandardError => e
            warn "Could not clear request_id (#{e.message})"
          end
        end
      end
    end
  end
end
