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

          def call(message, args = {})
            succeeded = false
            failed = false
            yield(args)
            succeeded = true
          rescue StandardError => err
            failed = true
            raise err
          ensure
            ack_or_reject(message, succeeded, failed, args)
          end

          private

          def ack_or_reject(message, succeeded, failed, args)
            id = message.message_id

            if succeeded
              message.acknowledge!
              logger.debug "Message(#{id}) was acknowledged"
            elsif failed
              seconds = calculate_backoff_seconds(message, args)
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

          def calculate_backoff_seconds(_message, args)
            amt = if args.key?(:attempts)
                    count = args[:attempts]
                    # min + exponential + random smear
                    15 + count**4 + (rand(30) * (count + 1))
                  else
                    60
                  end

            amt > 600 ? 600 : amt
          end
        end
      end
    end
  end
end
