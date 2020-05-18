# frozen_string_literal: true

module Hanami
  module Events
    module CloudPubsub
      module Middleware
        # Middleware used for logging useful information about an event
        class Prometheus
          attr_reader :events_counter

          def initialize
            require 'prometheus/client'
            prometheus = ::Prometheus::Client.registry
            @events_counter = prometheus.counter(
              :received_pubsub_events,
              docstring: 'A counter of received pubsub events',
              labels: %i[event_name subscription status]
            )
          end

          def call(msg, **opts)
            status = :running

            begin
              ret = yield(**opts)
              status = :succeeded
              ret
            rescue StandardError
              status = :failed
              raise
            end
          ensure
            sub = msg.subscription.subscriber.subscription_name
            event_name = msg.attributes['event_name']
            labels = { event_name: event_name, subscription: sub, status: status }
            events_counter.increment(labels: labels)
          end
        end
      end
    end
  end
end
