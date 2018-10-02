# frozen_string_literal: true

require 'hanami/events/cloud_pubsub/safe_error_handler'

module Hanami
  module Events
    module CloudPubsub
      # @api private
      class Listener
        class NoSubscriberError < StandardError; end

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

          listener = subscription.listen(subscriber_opts) do |message|
            handle_message(message)
          end

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
        rescue StandardError => err
          run_error_handlers(err, message)
          raise
        end

        def subscription_for(name)
          topic.create_subscription(name)
        rescue Google::Cloud::AlreadyExistsError
          topic.find_subscription(name)
        end

        def ensure_subscriber!
          raise NoSubscriberError, 'No subsriber has been registered' unless @subscriber
        end

        def run_error_handlers(err, message)
          CloudPubsub.error_handlers.each do |handler|
            SafeErrorHandler.call(handler, err, message)
          end
        end
      end
    end
  end
end
