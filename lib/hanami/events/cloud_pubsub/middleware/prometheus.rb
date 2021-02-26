# frozen_string_literal: true

module Hanami
  module Events
    module CloudPubsub
      module Middleware
        # Middleware used for logging useful information about an event
        class Prometheus
          Yabeda.configure do
            counter(
              :received_pubsub_events,
              tags: %i[event_name subscription status],
              comment: 'A counter of received pubsub events'
            )
          end

          def call(msg, **opts)
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
            record_metrics(msg, status)
          end

          private

          def record_metrics(msg, status)
            sub = msg.subscription.subscriber.subscription_name
            event_name = msg.attributes['event_name']
            labels = { event_name: event_name, subscription: sub, status: status }
            Yabeda.received_pubsub_events.increment(labels, by: 1)
          rescue StandardError
            # ok
          end
        end
      end
    end
  end
end
