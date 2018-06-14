# frozen_string_literal: true

require 'hanami/components'
require 'hanami/configuration'
require_relative 'integration'

module Hanami
  module Events
    module CloudPubsub
      # Register all the things needs to integrate with hanami
      module Register
        Integration::Setup.setup
      end
    end
  end
end
