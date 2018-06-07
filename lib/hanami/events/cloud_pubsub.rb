# frozen_string_literal: true

require 'hanami/events'
require 'hanami/events/cloud_pubsub/version'
require 'hanami/events/cloud_pubsub/runner'
require 'hanami/events/cloud_pubsub/mixin'
require 'google/cloud/pubsub'
require 'dry-configurable'

module Hanami
  module Events
    # CloudPubsub
    module CloudPubsub
      extend Dry::Configurable

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

      def self.setup
        Hanami::Events::Adapter.register(:cloud_pubsub) do
          require_relative 'adapter/cloud_pubsub'

          ::Hanami::Events::Adapter::CloudPubsub
        end
      end
    end
  end
end
