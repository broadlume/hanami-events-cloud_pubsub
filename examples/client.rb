# frozen_string_literal: true

ENV['PUBSUB_EMULATOR_HOST'] ||= 'localhost:8085'

require 'bundler/setup'

require 'google/cloud/pubsub'
require 'hanami/events'
require 'hanami/events/cloud_pubsub'

Hanami::Events::CloudPubsub.setup

pubsub = Google::Cloud::Pubsub.new project_id: 'emulator'

events = Hanami::Events.initialize(:cloud_pubsub, pubsub: pubsub, logger: Logger.new(STDOUT))

3.times do
  events.broadcast('user.deleted', user_id: 1)
end

events.adapter.flush_messages
