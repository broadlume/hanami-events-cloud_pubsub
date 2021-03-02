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

          def register_hanami_component
            ::Hanami::Components.register 'events' do
              requires 'logger', 'code'

              prepare { require 'hanami/events/cloud_pubsub' }

              resolve do |conf|
                CloudPubsub.configure do |config|
                  conf.cloud_pubsub.each { |blk| blk.call(config) }
                end

                require 'google/cloud/pubsub'

                ::Hanami::Events.initialize(
                  :cloud_pubsub,
                  pubsub: Google::Cloud::Pubsub.new,
                  logger: Hanami::Components['logger']
                )
              end
            end
          end

          def hook_into_all
            require 'hanami/components'
            # Unfortunately, hanami does not provide a way to add the component
            # requirements easily, so we take the old requirements and append 'events'
            requirements_for_all = ::Hanami::Components.component('all').send(:requirements)

            ::Hanami::Components.register 'all' do
              requires(*requirements_for_all, 'events')
              resolve { true }
            end
          end

          def add_configuration_helpers
            require 'hanami/utils/load_paths'
            require 'hanami/configuration'
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
        #       cloud_pubsub do |conf|
        #         conf.pubsub = { project_id: 'emulator' }
        #       end
        #     end
        #   end
        module Configuration
          def cloud_pubsub(&blk)
            if block_given?
              settings[:cloud_pubsub] ||= []
              settings[:cloud_pubsub] << blk
            end

            settings[:cloud_pubsub]
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
