# frozen_string_literal: true

module Hanami
  module Events
    module CloudPubsub
      module Middleware
        # Middleware used for logging useful information about an event
        class Prometheus
          LONG_RUNNING_JOB_RUNTIME_BUCKETS = [
            0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10, # standard (from Prometheus)
            30, 60, 120, 300, 1800, 3600, 21_600 # Tasks may be very long-running
          ].freeze

          Yabeda.configure do
            counter(
              :received_pubsub_events,
              tags: %i[event_name subscription status],
              comment: 'A counter of received pubsub events'
            )

            histogram :subscriber_runtime, comment: 'A histogram of the subscriber execution time.',
                                           unit: :seconds,
                                           per: :message,
                                           tags: %i[event_name subscription status],
                                           buckets: LONG_RUNNING_JOB_RUNTIME_BUCKETS
          end

          def call(msg, **opts)
            start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
            status = :running

            begin
              ret = yield(**opts) if block_given?
              status = :succeeded
              ret
            rescue StandardError
              status = :failed
              raise
            end
          ensure
            record_metrics(msg, status, start)
          end

          private

          def record_metrics(msg, status, start)
            elapsed = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - start).round(3)
            sub = msg.subscription.subscriber.subscription_name
            event_name = msg.attributes['event_name']
            labels = { event_name: event_name, subscription: sub, status: status }
            Yabeda.received_pubsub_events.increment(labels, by: 1)
            Yabeda.subscriber_runtime.measure(labels, elapsed)
          rescue StandardError
            # ok
          end
        end
      end
    end
  end
end
