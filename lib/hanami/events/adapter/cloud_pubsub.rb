# frozen_string_literal: true

require 'hanami/events/cloud_pubsub/listener'
require 'hanami/events/cloud_pubsub/subscriber'
require 'hanami/events/cloud_pubsub/errors'

module Hanami
  module Events
    class Adapter
      # Adapter for Google Cloud Pub/Sub
      #
      # @api private
      class CloudPubsub
        attr_reader :subscribers, :listeners, :topic_registry, :middleware

        def initialize(params)
          @pubsub = params[:pubsub]
          @logger = params[:logger] || Logger.new($stdout)
          @listen = params[:listen] || false
          @subscribers = Concurrent::Array.new
          @listeners = Concurrent::Array.new
          @serializer_type = params.fetch(:serializer, :json).to_sym
          @topic_registry = {}
          @mutex = Mutex.new
          @middleware = ::Hanami::Events::CloudPubsub.config.client_middleware
        end

        # Brodcasts event to all subscribes
        #
        # @param event [Symbol, String] the event name
        # @param payload [Hash] the event data
        def broadcast(name, input_payload, **message_opts)
          event_name = namespaced(name)
          topic = topic_for event_name
          serialized_payload = serializer.serialize(input_payload)
          attrs = { id: SecureRandom.uuid, event_name: event_name }

          middleware.invoke(serialized_payload, **attrs, **message_opts) do |payload, **opts|
            topic.publish_async(payload, **opts) do |result|
              msg = result.message.grpc.to_h

              if result.succeeded?
                logger.info "Published #{name.inspect} published", **msg
              else
                logger.warn "Failed to broadcast #{name.inspect} event", error: result.error, **msg # rubocop:disable Layout/LineLength
              end
            end
          end
        end

        # Subscribes block for selected event
        #
        # @param event_name [Symbol, String] the event name
        # @param id [String] A unique identifier for the subscriber
        # @param subscriber_opts [String] Additional options for the subscriber
        # @param block [Block] to execute when event is broadcasted
        def subscribe(name, id:, auto_ack: true, **subscriber_opts, &block)
          event_name = namespaced(name)
          namespaced_id = namespaced(id)

          logger.debug("Subscribed listener \"#{id}\" for event \"#{event_name}\"")

          sub = Hanami::Events::CloudPubsub::Subscriber.new(event_name, block, logger)
          @subscribers << sub
          topic = topic_for event_name

          register_listener(event_name, topic, namespaced_id, auto_ack, subscriber_opts)
        end

        def flush_messages
          pubs = topic_registry.values.map(&:async_publisher).compact
          pubs.each(&:stop).map(&:wait!)
        end

        private

        attr_reader :logger

        def register_listener(event_name, topic, subscriber_id, auto_ack, subscriber_opts)
          listener = ::Hanami::Events::CloudPubsub::Listener.new(
            subscriber_id: subscriber_id,
            event_name: event_name,
            handler: method(:call_subscribers),
            logger: logger,
            topic: topic,
            subscriber_opts: subscriber_opts,
            dead_letter_topic: dead_letter_topic,
            auto_ack: auto_ack
          )

          @listeners << listener
          listener.register
        end

        def call_subscribers(message)
          data = message.data
          payload = serializer.deserialize(data)
          event_name = message.attributes['event_name']

          @subscribers.each do |subscriber|
            subscriber.call(event_name, payload, message)
          end
        end

        def serializer
          @serializer ||= Hanami::Events::Serializer[@serializer_type].new
        end

        # rubocop:disable Layout/LineLength
        def topic_for(name)
          return @topic_registry[name.to_s] if @topic_registry[name.to_s]

          topic = @pubsub.find_topic(name) ||
                  (Hanami::Events::CloudPubsub.auto_create_topics && @pubsub.create_topic(name)) ||
                  raise(::Hanami::Events::CloudPubsub::Errors::TopicNotFoundError, "no topic named: #{name}")

          topic.enable_message_ordering!

          @topic_registry[name.to_s] = topic
        end
        # rubocop:enable Layout/LineLength

        def dead_letter_topic
          conf = Hanami::Events::CloudPubsub.config.auto_retry

          return unless conf.enabled

          topic_for namespaced(conf.dead_letter_topic_name)
        end

        def namespaced(val, sep: '.')
          [Hanami::Events::CloudPubsub.namespace, val].compact.join(sep)
        end
      end
    end
  end
end
