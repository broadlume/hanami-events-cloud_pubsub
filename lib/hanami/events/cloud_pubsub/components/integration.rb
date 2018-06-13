# frozen_string_literal: true

module Hanami
  module Events
    module CloudPubsub
      module Integration
        # Helpers use to setup all integration with hanami
        module Setup
          module_function

          def setup
            register_events_adapter
            register_hanami_component
            hook_into_all
            add_configuration_helpers
          end

          def register_events_adapter
            ::Hanami::Events::Adapter.register(:cloud_pubsub) do
              require 'hanami/events/adapter/cloud_pubsub'
              ::Hanami::Events::Adapter::CloudPubsub
            end
          end

          # rubocop:disable Metrics/MethodLength
          def register_hanami_component
            ::Hanami::Components.register 'events' do
              requires 'logger'

              prepare { require 'hanami/events/cloud_pubsub' }

              resolve do |conf|
                settings = conf.send :settings
                pubsub_settings = settings.fetch(:pubsub, {})

                ::Hanami::Events.initialize(
                  :cloud_pubsub,
                  pubsub: Google::Cloud::Pubsub.new(pubsub_settings),
                  logger: Hanami::Components['logger']
                )
              end
            end
          end
          # rubocop:enable Metrics/MethodLength

          def hook_into_all
            # Unfortunately, hanami does not provide a way to add the component
            # requirements easily, so we take the old requirements and append 'events'
            requirements_for_all = ::Hanami::Components.component('all').send(:requirements)

            ::Hanami::Components.register 'all' do
              requires 'events', *requirements_for_all
              resolve { true }
            end
          end

          def add_configuration_helpers
            ::Hanami::Configuration.include(Integration::Configuration)
            ::Hanami.extend Integration::EasyAccess
          end
        end

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

        # Easy access to events, i.e. Hanami.events
        module EasyAccess
          def events
            Hanami::Components['events']
          end
        end
      end
    end
  end
end
