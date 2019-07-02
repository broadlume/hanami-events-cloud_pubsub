# frozen_string_literal: true

module Hanami
  module Events
    module CloudPubsub
      # Middleware
      module Middleware
        # Middleware used for automatically acknowledging messages
        class AutoRetry
          attr_reader :max_attempts

          def initialize(logger: nil, max_attempts: 1200)
            @logger = logger
            @max_attempts = max_attempts
          end

          def call(message, args = {})
            succeeded = false
            failed = false
            yield(args)
            succeeded = true
          rescue StandardError => e
            failed = true
            raise e
          ensure
            ack_or_reject(message, succeeded, failed, args)
          end

          private

          def ack_or_reject(message, succeeded, failed, args)
            if succeeded
              handle_success(message, args)
            elsif failed && max_attempts_reached?(args)
              handle_max_attempts_reached(message, args)
            elsif failed
              handle_failure(message, args)
            else
              handle_unfinished(message, args)
            end
          end

          def handle_success(message, _args)
            message.acknowledge!
            logger.debug "Message(#{message.message_id}) was acknowledged"
          end

          def max_attempts_reached?(args)
            args.key?(:attempts) && args[:attempts] >= max_attempts
          end

          def handle_max_attempts_reached(message, _args)
            id = message.message_id
            msg = 'number of attempts exceeded max attempts ' \
                  "of #{max_attempts}, acknowledging message"
            logger.debug "Message(#{id}) failed, #{msg}"
            message.acknowledge!
          end

          def handle_failure(message, args)
            id = message.message_id
            seconds = calculate_backoff_seconds(message, args)
            success = message.modify_ack_deadline!(seconds)
            msg = "added #{success ? seconds : 0} seconds of delay to ack deadline"
            logger.debug "Message(#{id}) failed, #{msg}" if success
          end

          def handle_unfinished(message, _args)
            id = message.message_id
            message.reject!
            logger.warn "Message(#{id}) was terminated from outside, rescheduling"
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
