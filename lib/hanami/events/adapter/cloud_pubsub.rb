# frozen_string_literal: true

require 'hanami/events/cloud_pubsub/listener'

module Hanami
  module Events
    class Adapter
      # Adapter for Google Cloud Pub/Sub
      #
      # @api private
      class CloudPubsub
        attr_reader :subscribers, :listeners, :topic_registry

        def initialize(params)
          @pubsub = params[:pubsub]
          @logger = params[:logger] || Logger.new(STDOUT)
          @listen = params[:listen] || false
          @subscribers = Concurrent::Array.new
          @listeners = Concurrent::Array.new
          @serializer_type = params.fetch(:serializer, :json).to_sym
          @topic_registry = {}
          @mutex = Mutex.new
        end

        # Brodcasts event to all subscribes
        #
        # @param event [Symbol, String] the event name
        # @param payload [Hash] the event data
        def broadcast(event_name, payload)
          topic = topic_for event_name
          payload = serializer.serialize(payload)
          attributes = { id: SecureRandom.uuid, event_name: event_name }

          topic.publish_async(payload, attributes) do |result|
            logger.info "Published event #{result.inspect}"
          end
        end

        # Subscribes block for selected event
        #
        # @param event_name [Symbol, String] the event name
        # @param block [Block] to execute when event is broadcasted
        def subscribe(event_name, &block)
          return false unless listening?

          @subscribers << Subscriber.new(event_name, block, logger)
          topic = topic_for event_name

          register_listener(event_name, topic)
        end

        def flush_messages
          pubs = topic_registry.values.map(&:async_publisher).compact
          pubs.each(&:stop).map(&:wait!)
        end

        def listen(should_listen = true)
          @listen = should_listen
          self
        end

        def listening?
          !!@listen # rubocop:disable Style/DoubleNegation
        end

        private

        attr_reader :logger

        def register_listener(event_name, topic)
          listener = ::Hanami::Events::CloudPubsub::Listener.new(
            event_name: event_name,
            handler: method(:call_subscribers),
            logger: logger,
            topic: topic
          )

          @listeners << listener
          listener.register
        end

        def call_subscribers(message)
          data = message.data
          payload = serializer.deserialize(data)
          event_name = message.attributes['event_name']
          payload['id'] = message.attributes['id']

          @subscribers.each do |subscriber|
            subscriber.call(event_name, payload)
          end
        end

        def serializer
          @serializer ||= Hanami::Events::Serializer[@serializer_type].new
        end

        def topic_for(event_name)
          @topic_registry[event_name.to_s] ||=
            begin
              @pubsub.find_topic(event_name) || @pubsub.create_topic(event_name)
            end
        end
      end
    end
  end
end
