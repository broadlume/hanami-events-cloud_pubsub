# frozen_string_literal: true

module Hanami
  module Events
    module CloudPubsub
      # Middleware
      module Middleware
        # Middleware used for automatically acknowledging messages
        class AutoRetry
          def initialize(logger: nil)
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

            if succeeded
              message.acknowledge!
              logger.debug "Message(#{id}) was acknowledged"
            elsif failed
              seconds = calculate_backoff_seconds(message)
              success = message.modify_ack_deadline!(seconds)
              msg = "added #{success ? seconds : 0} seconds of delay to ack deadline"
              logger.debug "Message(#{id}) failed, #{msg}" if success
            else
              message.reject!
              logger.warn "Message(#{id}) was terminated from outside, rescheduling"
            end
          end

          def logger
            @logger || CloudPubsub.logger
          end

          def calculate_backoff_seconds(_message)
            # Figure out a way to keep track of retries
            60
          end
        end
      end
    end
  end
end
