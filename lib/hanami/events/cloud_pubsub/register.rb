# frozen_string_literal: true

require 'hanami/components'

Hanami::Components.register 'events' do
  requires 'logger'

  prepare do
    require 'hanami/events/cloud_pubsub'
    Hanami::Configuration.include(Hanami::Events::CloudPubsub::Components::Configuration)
  end

  resolve do |conf|
    settings = conf.send :settings
    Hanami::Events::CloudPubsub.setup
    pubsub = Google::Cloud::Pubsub.new(settings[:pubsub])

    Hanami::Events.initialize(
      :cloud_pubsub,
      pubsub: pubsub,
      logger: Hanami::Components['logger']
    )
  end
end

Hanami::Events::Adapter.register(:cloud_pubsub) do
  require_relative 'hanami/events/adapter/cloud_pubsub'

  ::Hanami::Events::Adapter::CloudPubsub
end
