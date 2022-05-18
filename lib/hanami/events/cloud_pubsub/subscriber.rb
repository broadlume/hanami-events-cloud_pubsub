# frozen_string_literal: true

module Hanami
  module Events
    module CloudPubsub
      # Subscriber class for calling subscriber blocks, with extra support for
      # passing the raw message.
      #
      # @since 0.1.0
      #
      # @api private
      class Subscriber < ::Hanami::Events::Subscriber
        def initialize(event_name, handler, logger: nil, data_struct_class: nil)
          super
          @handler = handler
        end

        def call(event_name, payload, message)
          return unless @pattern_matcher.match?(event_name)

          data_object = @data_struct_class ? @data_struct_class.new(payload) : payload

          if @handler.arity == 2
            @handler.call(data_object, message)
          else
            @handler.call(data_object)
          end
        end
      end
    end
  end
end
