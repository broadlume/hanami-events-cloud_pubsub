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

      def self.setup
        Hanami::Events::Adapter.register(:cloud_pubsub) do
          require_relative 'adapter/cloud_pubsub'

          ::Hanami::Events::Adapter::CloudPubsub
        end
      end
    end
  end
end
