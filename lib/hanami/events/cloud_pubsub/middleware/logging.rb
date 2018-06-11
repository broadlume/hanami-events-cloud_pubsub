# frozen_string_literal: true

module Hanami
  module Events
    module CloudPubsub
      module Middleware
        # Middleware used for logging useful information about an event
        class Logging
          def initialize(logger: nil)
            @logger = logger
          end

          def call(msg, *_args)
            started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
            yield
          ensure
            ended_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
            seconds = ended_at - started_at
            logger.info <<~MSG
              Processed message(id: #{msg.id}) took #{seconds} seconds to process
            MSG
          end

          private

          def logger
            @logger || CloudPubsub.logger
          end
        end
      end
    end
  end
end
