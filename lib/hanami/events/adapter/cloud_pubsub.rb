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
        def broadcast(name, payload)
          event_name = namespaced(name)
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
        # @param id [String] A unique identifier for the subscriber
        # @param subscriber_opts [String] Additional options for the subscriber
        # @param block [Block] to execute when event is broadcasted
        def subscribe(name, id:, **subscriber_opts, &block)
          event_name = namespaced(name)
          namespaced_id = namespaced(id)

          logger.debug("Subscribed listener \"#{id}\" for event \"#{event_name}\"")

          @subscribers << Subscriber.new(event_name, block, logger)
          topic = topic_for event_name

          register_listener(event_name, topic, namespaced_id, subscriber_opts)
        end

        def flush_messages
          pubs = topic_registry.values.map(&:async_publisher).compact
          pubs.each(&:stop).map(&:wait!)
        end

        private

        attr_reader :logger

        def register_listener(event_name, topic, subscriber_id, subscriber_opts)
          listener = ::Hanami::Events::CloudPubsub::Listener.new(
            subscriber_id: subscriber_id,
            event_name: event_name,
            handler: method(:call_subscribers),
            logger: logger,
            topic: topic,
            subscriber_opts: subscriber_opts
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

        def topic_for(name)
          @topic_registry[name.to_s] ||= begin
            @pubsub.find_topic(name) ||
              (CloudPubsub.auto_create_topics && @pubsub.create_topic(name)) ||
              raise(CloudPubsub::Errors::TopicNotFoundError, "no topic named: #{name}")
          end
        end

        def namespaced(val, sep: '.')
          [Hanami::Events::CloudPubsub.namespace, val].compact.join(sep)
        end
      end
    end
  end
end
