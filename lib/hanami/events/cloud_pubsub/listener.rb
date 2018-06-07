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
                    :event_name

        def initialize(topic:, logger:, handler:, event_name:, subscriber_id:)
          @topic = topic
          @logger = logger
          @handler = handler
          @event_name = event_name
          @subscriber_id = subscriber_id
        end

        def register
          subscription = subscription_for(subscriber_id)

          listener = subscription.listen do |message|
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

        #:reek:TooManyStatements
        #:reek:DuplicateMethodCall
        # rubocop:disable Metrics/MethodLength
        def run_handler(message)
          succeeded = false
          failed = false
          handler.call(message)
          succeeded = true
        rescue Exception => err # rubocop:disable all
          failed = true
          run_error_handlers(err, message)
          raise err
        ensure
          id = message.message_id
          if succeeded || failed
            message.acknowledge!
            logger.debug "Message(#{id}) was acknowledged"
          else
            message.reject!
            logger.warn "Message(#{id}) was terminated from outside, rescheduling"
          end
        end
        # rubocop:enable Metrics/MethodLength

        def subscription_for(name)
          topic.create_subscription(name)
        rescue Google::Cloud::AlreadyExistsError
          # OK
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
