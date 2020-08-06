# frozen_string_literal: true

require 'hanami/events/cloud_pubsub/safe_error_handler'

module Hanami
  module Events
    module CloudPubsub
      # @api private
      class Listener
        attr_reader :topic,
                    :subscriber,
                    :subscriber_id,
                    :logger,
                    :handler,
                    :event_name,
                    :subscriber_opts,
                    :middleware
        # rubocop:disable Metrics/ParameterLists
        def initialize(topic:,
                       logger:,
                       handler:,
                       event_name:,
                       subscriber_id:,
                       subscriber_opts: {},
                       middleware: CloudPubsub.config.middleware)
          @topic = topic
          @logger = logger
          @handler = handler
          @event_name = event_name
          @subscriber_id = subscriber_id
          @subscriber_opts = CloudPubsub.config.subscriber.to_h.merge(subscriber_opts)
          @middleware = middleware
        end
        # rubocop:enable Metrics/ParameterLists

        def register
          subscription = subscription_for(subscriber_id)

          listener = subscription.listen(**subscriber_opts) do |message|
            handle_message(message)
          end

          logger.debug("Registered listener for #{subscriber_id} with opts #{subscriber_opts}")

          @subscriber = listener

          self
        end

        def start
          ensure_subscriber!
          @subscriber.start
        end

        def started?
          @subscriber&.started?
        end

        def shutdown
          subscriber.stop.wait!
          self
        end

        def stop
          subscriber.stop
          self
        end

        def wait
          subscriber.wait!
          self
        end

        def format
          subscriber.to_s
        end

        private

        def handle_message(msg)
          run_handler(msg)
        end

        def run_handler(message)
          middleware.invoke(message) { handler.call(message) }
        rescue StandardError => e
          run_error_handlers(e, message)
          raise
        end

        def subscription_for(name)
          found_subscription = topic.find_subscription(name)

          if found_subscription
            ensure_topic_names_match!(name, found_subscription)
            found_subscription
          elsif CloudPubsub.auto_create_subscriptions
            topic.create_subscription(name)
          else
            raise Errors::SubscriptionNotFoundError, "no subscription named: #{name}"
          end
        end

        def ensure_subscriber!
          raise Errors::NoSubscriberError, 'No subsriber has been registered' unless @subscriber
        end

        def run_error_handlers(err, message)
          CloudPubsub.error_handlers.each do |handler|
            SafeErrorHandler.call(handler, err, message)
          end
        end

        def ensure_topic_names_match!(sub_name, found_subscription)
          parsed_name = found_subscription.topic.name.split('/').last

          return true if parsed_name == @event_name

          raise Errors::SubscriptionTopicNameMismatch,
                "a subscription already exists for #{sub_name} " \
                "but its name #{found_subscription.topic.name} does not match #{@event_name}"
        end
      end
    end
  end
end
