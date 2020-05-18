# frozen_string_literal: true

require 'hanami/events/cloud_pubsub/middleware/stack'
module Hanami
  module Events
    module CloudPubsub
      module Middleware
        RSpec.describe Stack do
          subject(:stack) { described_class.new }

          describe '#prepend' do
            it 'adds middleware to the stack' do
              old_middleware = double(call: true)
              new_middleware = double(call: true)
              stack << old_middleware
              stack.prepend new_middleware

              expect(stack.entries.first).to eql(new_middleware)
              expect(stack.entries.last).to eql(old_middleware)
            end

            it 'raises an error if the middleware does not respond to #call' do
              middleware = double

              expect do
                stack.prepend middleware
              end.to raise_error(Stack::InvalidMiddlewareError)
            end
          end

          describe '#<<' do
            it 'adds middleware to the stack' do
              middleware = double(call: true)
              stack << middleware

              expect(stack.entries).to contain_exactly(middleware)
            end

            it 'raises an error if the middleware does not respond to #call' do
              middleware = double

              expect do
                stack << middleware
              end.to raise_error(Stack::InvalidMiddlewareError)
            end
          end

          describe '#invoke' do
            let(:message) { %i[foo bar] }
            let(:handler) { double(call: true) }
            let(:first_call_stub) { double(call: true) }
            let(:second_call_stub) { double(call: true) }
            let(:third_call_stub) { double(call: true) }
            let(:middleware) do
              Class.new do
                def initialize(recorder, **opts)
                  @recorder = recorder
                  @opts = opts
                end

                def call(*args, **opts)
                  @recorder.call(*args, **opts.merge(@opts))
                  yield(*args, **opts.merge(@opts))
                end
              end
            end

            it 'passes args to each middleware in the stack' do
              stack << middleware.new(first_call_stub)
              stack << middleware.new(second_call_stub, test: true)
              stack << middleware.new(third_call_stub)

              stack.invoke(message) { |msg| handler.call(msg) }

              expect(second_call_stub).to have_received(:call).with(message, test: true)
              expect(third_call_stub).to have_received(:call).with(message, test: true)
              expect(handler).to have_received(:call).with(message)
            end

            it 'halts the chain if a middleware does not yield' do
              non_yielding_middleware = middleware.new(first_call_stub)
              allow(non_yielding_middleware).to receive(:call)

              stack << non_yielding_middleware
              stack.invoke(message) { |msg| handler.call(msg) }

              expect(handler).not_to have_received(:call).with(message)
            end

            it 'bubbles errors' do
              stack << proc { raise 'Oh no' }

              expect { stack.invoke(message) }.to raise_error 'Oh no'
            end
          end
        end
      end
    end
  end
end
