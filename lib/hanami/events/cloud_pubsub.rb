# frozen_string_literal: true

require 'hanami/events'
require 'hanami/events/cloud_pubsub/version'
require 'hanami/events/cloud_pubsub/middleware/stack'
require 'hanami/events/cloud_pubsub/middleware/logging'
require 'hanami/events/cloud_pubsub/middleware/auto_acknowledge'
require 'hanami/events/cloud_pubsub/runner'
require 'google/cloud/pubsub'
require 'dry-configurable'

module Hanami
  module Events
    # CloudPubsub
    module CloudPubsub
      extend Dry::Configurable

      setting :subscriber, reader: true do
        setting :streams, 4
        setting :threads do
          setting :callback, 8
          setting :push, 4
        end
      end
      setting :project_id, reader: true
      setting :logger, Logger.new(STDOUT), reader: true
      setting :subscriptions_loader, proc {
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
      setting :error_handlers, [
        ->(err, msg) do
          logger.error "Message(#{msg.message_id}) failed with exception #{err.inspect}"
        end
      ], reader: true

      setting :middleware, Middleware::Stack.new(
        Middleware::Logging.new,
        Middleware::AutoAcknowledge.new
      )
    end
  end
end
