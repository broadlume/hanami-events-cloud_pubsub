# frozen_string_literal: true

module Hanami
  module Events
    module CloudPubsub
      module Middleware
        module Client
          # Broadcasts events with current request id
          class RequestId
            def call(payload, attributes = {})
              attributes.merge!(
                request_id: ::RequestId.request_id || SecureRandom.uuid
              )

              yield(payload, **attributes)
            end
          end
        end
      end
    end
  end
end
