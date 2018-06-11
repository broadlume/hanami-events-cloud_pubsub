# frozen_string_literal: true

module Hanami
  module Events
    module CloudPubsub
      # Middleware
      module Middleware
        # Middleware used for automatically acknowledging messages
        class AutoAcknowledge
          attr_reader :logger

          def initialize(logger:)
            @logger = logger
          end

          def call(message, *_args)
            succeeded = false
            failed = false
            yield
            succeeded = true
          rescue StandardError => err
            failed = true
            raise err
          ensure
            ack_or_reject(message, succeeded, failed)
          end

          private

          def ack_or_reject(message, succeeded, failed)
            id = message.message_id

            if succeeded || failed
              message.acknowledge!
              logger.debug "Message(#{id}) was acknowledged"
            else
              message.reject!
              logger.warn "Message(#{id}) was terminated from outside, rescheduling"
            end
          end
        end
      end
    end
  end
end
