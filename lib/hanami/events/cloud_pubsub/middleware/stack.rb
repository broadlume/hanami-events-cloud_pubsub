# frozen_string_literal: true

module Hanami
  module Events
    module CloudPubsub
      module Middleware
        # Middleware which is invoked when a message is received
        class Stack
          # Error raised when middleware is not callable
          class InvalidMiddlewareError < ArgumentError
            def initialize(middleware)
              super <<~MSG
                Attempted to add middleware which is not callable: #{middleware.inspect}
                Make sure that your middleware responds to the #call method
              MSG
            end
          end

          attr_reader :entries

          def initialize
            @entries = []
            yield self if block_given?
          end

          def <<(middleware)
            ensure_callable(middleware)
            entries << middleware
          end

          def shift
            @entries.shift
          end

          def invoke(*args)
            stack = entries.dup

            traverse_stack = lambda do
              if stack.empty?
                yield(*args)
              else
                stack.shift.call(*args, &traverse_stack)
              end
            end

            traverse_stack.call
          end

          private

          def ensure_callable(middleware)
            raise InvalidMiddlewareError, middleware unless middleware.respond_to?(:call)
          end
        end
      end
    end
  end
end
