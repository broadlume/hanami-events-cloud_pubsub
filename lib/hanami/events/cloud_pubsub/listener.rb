# frozen_string_literal: true

module Hanami
  module Events
    module CloudPubsub
      # @api private
      class Listener
        class NoSubscriberError < StandardError; end

        attr_reader :topic,
                    :subscriber,
                    :logger,
                    :handler,
                    :event_name

        def initialize(topic:, logger:, handler:, event_name:)
          @topic = topic
          @logger = logger
          @handler = handler
          @event_name = event_name
        end

        def register
          subscription = subscription_for(event_name)

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

        def shutdown
          subscriber.stop.wait!
          self
        end

        def kill!
          subscriber.stop!
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
        # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
        def run_handler(message)
          id = message.message_id
          succeeded = false
          failed = false
          handler.call(message)
          succeeded = true
        rescue Exception => err # rubocop:disable all
          failed = true
          logger.error "Message(#{id}) failed with exception #{err.inspect}"
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
        # rubocop:enable Metrics/MethodLength, Metrics/AbcSize

        def subscription_for(name)
          topic.find_subscription(name) || topic.create_subscription(name)
        end

        def ensure_subscriber!
          raise NoSubscriberError, 'No subsriber has been registererd' unless @subscriber
        end
      end
    end
  end
end
