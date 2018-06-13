# frozen_string_literal: true

module Hanami
  module Events
    module CloudPubsub
      module Components
        # Extra configuration methods for Hanami
        #
        # @example Use emulator in development
        #   # config/environment.rb
        #   Hanami.configure do
        #     environment :development do
        #       pubsub project_id: 'emulator'
        #     end
        #   end
        module Configuration
          def pubsub(value = nil)
            if value.nil?
              settings.fetch(:pubsub, nil)
            else
              settings[:pubsub] = value
            end
          end
        end
      end
    end
  end
end
