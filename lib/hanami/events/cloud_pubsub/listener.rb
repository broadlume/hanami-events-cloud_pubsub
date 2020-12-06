# frozen_string_literal: true

require 'hanami/events/cloud_pubsub/safe_error_handler'

module Hanami
  module Events
    module CloudPubsub
      # rubocop:disable Metrics/ClassLength:
      # @api private
      class Listener
        attr_reader :topic,
                    :subscriber,
                    :subscriber_id,
                    :logger,
                    :handler,
                    :event_name,
                    :input_subscriber_opts,
                    :middleware,
                    :dead_letter_topic

        # rubocop:disable Metrics/ParameterLists
        def initialize(topic:,
                       logger:,
                       handler:,
                       event_name:,
                       subscriber_id:,
                       subscriber_opts: {},
                       middleware: CloudPubsub.config.middleware,
                       dead_letter_topic: nil)
          @topic = topic
          @logger = logger
          @handler = handler
          @event_name = event_name
          @subscriber_id = subscriber_id
          @input_subscriber_opts = subscriber_opts
          @middleware = middleware
          @dead_letter_topic = dead_letter_topic
        end
        # rubocop:enable Metrics/ParameterLists

        def register
          subscription = subscription_for(subscriber_id)
          apply_retry_options(subscription)
          listener = subscription.listen(**subscriber_options) { |m| handle_message(m) }
          logger.debug("Registered listener for #{subscriber_id} with: #{subscriber_options}")

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
          message.ack!
        rescue StandardError => e
          run_error_handlers(e, message)
          message.nack! if CloudPubsub.config.auto_retry.enabled
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

        def subscriber_options
          @subscriber_options ||= {
            **CloudPubsub.config.subscriber.to_h,
            **input_subscriber_opts
          }
        end

        def apply_retry_options(sub)
          return {} unless CloudPubsub.config.auto_retry.enabled

          sub.retry_policy = Google::Cloud::PubSub::RetryPolicy.new(
            minimum_backoff: CloudPubsub.config.auto_retry.minimum_backoff,
            maximum_backoff: CloudPubsub.config.auto_retry.maximum_backoff
          )
          sub.dead_letter_topic = dead_letter_topic
          sub.dead_letter_max_delivery_attempts = CloudPubsub.config.auto_retry.max_attempts

          sub
        rescue StandardError => e
          run_error_handlers(e, "Faled to apply retry options (see https://github.com/googleapis/google-cloud-ruby/issues/8237)")
        end
      end
      # rubocop:enable Metrics/ClassLength:
    end
  end
end
