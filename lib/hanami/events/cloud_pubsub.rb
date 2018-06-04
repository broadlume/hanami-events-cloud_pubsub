# frozen_string_literal: true

require 'hanami/events'
require 'hanami/events/cloud_pubsub/version'
require 'hanami/events/cloud_pubsub/runner'
require 'google/cloud/pubsub'

module Hanami
  module Events
    # CloudPubsub
    module CloudPubsub
      def self.setup
        Hanami::Events::Adapter.register(:cloud_pubsub) do
          require_relative 'adapter/cloud_pubsub'

          ::Hanami::Events::Adapter::CloudPubsub
        end
      end
    end
  end
end
