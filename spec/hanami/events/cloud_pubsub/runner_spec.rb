# frozen_string_literal: true

module Hanami
  module Events
    module CloudPubsub
      RSpec.describe Runner do
        let(:listener) { double(start: true, stop: true, wait: true) }
        let(:logger) { double(info: true) }
        let(:adapter) do
          double(listeners: [listener], flush_messages: true)
        end

        subject(:runner) do
          described_class.new logger: logger, adapter: adapter, sleep_time: 0
        end

        describe '#start' do
          it 'starts all the listeners' do
            expect(logger).to receive(:info).with(/Starting/)
            expect(listener).to receive(:start)
            runner.start
          end
        end

        describe '#gracefully_shutdown' do
          it 'tells the adapter to flush all messages' do
            expect(adapter).to receive(:flush_messages)
            runner.gracefully_shutdown
          end

          it 'stops all the listeners' do
            expect(listener).to receive(:stop)
            runner.gracefully_shutdown
          end

          it 'waits on all the listeners' do
            expect(listener).to receive(:wait)
            runner.gracefully_shutdown
          end

          it 'logs a message' do
            expect(logger).to receive(:info).with(/Gracefully shutting down/)
            runner.gracefully_shutdown
          end
        end

        describe '#pause' do
          it 'stops all the listeners' do
            expect(listener).to receive(:stop)
            runner.pause
          end

          it 'logs a message' do
            expect(logger).to receive(:info).with(/Pausing/)
            runner.pause
          end
        end

        describe '#ready?' do
          it 'ready when all the listeners have started' do
            allow(listener).to receive(:started?).and_return(true)
            expect(runner).to be_ready
          end

          it 'is not ready when a listener has not started' do
            allow(listener).to receive(:started?).and_return(false)
            expect(runner).not_to be_ready
          end
        end
      end
    end
  end
end
