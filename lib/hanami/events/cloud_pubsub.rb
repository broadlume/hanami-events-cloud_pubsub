# frozen_string_literal: true

require 'concurrent/async'
require 'hanami/events'
require 'hanami/events/cloud_pubsub/version'
require 'hanami/events/cloud_pubsub/middleware/stack'
require 'hanami/events/cloud_pubsub/middleware/logging'
require 'hanami/events/cloud_pubsub/runner'
require 'hanami/events/cloud_pubsub/errors'
require 'dry-configurable'

module Hanami
  module Events
    # CloudPubsub
    module CloudPubsub
      extend Dry::Configurable

      setting :namespace, reader: true

      setting :subscriber, reader: true do
        setting :streams, default: 4
        setting :threads do
          setting :callback, default: 8
          setting :push, default: 4
        end
      end

      setting :pubsub, default: {}, reader: true

      setting :project_id, reader: true
      setting :auto_create_subscriptions, default: false, reader: true
      setting :auto_create_topics, default: false, reader: true
      setting :logger, default: Logger.new($stdout), reader: true
      setting :subscriptions_loader, default: proc {
        abort <<~MSG
          ┌────────────────────────────────────────────────────────────────────────────────┐
          │ You must configure subscriptions_loader param in order to be able to subscribe │
          │ to events. When the worker is setup and ready to subscribe to events, this     │
          │ loader will be called. It must respond to `#call`.                             │
          │                                                                                │
          │ Example                                                                        │
          │ ═══════                                                                        │
          │                                                                                │
          │ Hanami::Events::CloudPubsub.configure do │config│                              │
          │   config.subscriptions_loader = proc do                                        │
          │     Hanami::Utils.require! 'apps/web/subscriptions'                            │
          │   end                                                                          │
          │ end                                                                            │
          └────────────────────────────────────────────────────────────────────────────────┘
        MSG
      }, reader: true
      setting :error_handlers, default: [
        ->(err, msg) do
          logger.error "Message(#{msg}) failed with exception #{err.inspect}"
        end
      ], reader: true

      middleware_stack = Middleware::Stack.new(
        Middleware::Logging.new
      )

      if defined?(Yabeda::Prometheus::Exporter)
        begin
          require 'hanami/events/cloud_pubsub/middleware/prometheus'
          middleware_stack << Middleware::Prometheus.new
        rescue LoadError
          # ok
        end
      end

      setting :middleware, default: middleware_stack

      client_middleware_stack = Middleware::Stack.new

      begin
        require 'request_id'
        require 'hanami/events/cloud_pubsub/middleware/client/request_id'
        require 'hanami/events/cloud_pubsub/middleware/request_id'

        client_middleware_stack.prepend(Middleware::Client::RequestId.new)
        middleware_stack.prepend(Middleware::RequestId.new)
      rescue LoadError
        # ok
      end

      setting :client_middleware, default: client_middleware_stack

      setting :on_shutdown_handlers, default: [], reader: true

      setting :auto_retry do
        setting :enabled, default: false
        setting :max_attempts, default: 1200
        setting :dead_letter_topic_name
        setting :minimum_backoff, default: 30
        setting :maximum_backoff, default: 600
      end

      def self.finalize_settings!
        require 'google/cloud/pubsub'
        conf_hash = config.pubsub
        conf_hash.each { |key, val| Google::Cloud::Pubsub.configure[key] = val }
      end
    end
  end
end
