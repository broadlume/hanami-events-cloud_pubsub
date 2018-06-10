# frozen_string_literal: true

module Hanami
  module Events
    module CloudPubsub
      module Middleware
        # Middleware used for logging useful information about an event
        class Logging
          attr_reader :logger

          def initialize(logger)
            @logger = logger
          end

          def call(*_args)
            started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
            yield
          ensure
            ended_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
            total_time = ended_at - started_at
            logger.info "Event took #{total_time} seconds to process"
          end
        end
      end
    end
  end
end
