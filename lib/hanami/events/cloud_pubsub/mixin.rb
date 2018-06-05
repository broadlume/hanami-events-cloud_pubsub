# frozen_string_literal: true

module Hanami
  module Events
    module CloudPubsub
      # Mixin that extends class by `subscribe_to` method.
      #
      # @example
      # $events = Hanami::Events.initialize(:memory)
      #
      # class WelcomeMailer
      #   include Hanami::Events::Mixin
      #
      #   subscribe_to $events, 'user.created', id: 'welcome-mailer'
      #
      #   def call(payload)
      #     # send email
      #   end
      # end
      #
      # @since 0.1.0
      #
      # @api public
      module Mixin
        def self.included(klass)
          klass.extend(ClassMethods)
        end

        # Class interfaces
        module ClassMethods
          def subscribe_to(event_bus, event_name, id:)
            klass = self
            event_bus.subscribe(event_name, id: id) { |payload| klass.new.call(payload) }
          end
        end
      end
    end
  end
end
