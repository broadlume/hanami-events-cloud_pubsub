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
              :pubsub_events,
              docstring: 'A counter of received pubsub events',
              labels: %i[event_name subscription]
            )
          end

          def call(msg, opts = {})
            yield(opts)
          ensure
            sub = msg.subscription.subscriber.subscription_name
            event_name = msg.attributes['event_name']
            events_counter.increment(labels: { event_name: event_name, subscription: sub })
          end
        end
      end
    end
  end
end
