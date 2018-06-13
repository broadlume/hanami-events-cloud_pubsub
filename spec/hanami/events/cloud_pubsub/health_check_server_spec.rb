# frozen_string_literal: true

require_relative './../../../../lib/hanami/events/cloud_pubsub/health_check_server'

module Hanami
  module Events
    module CloudPubsub
      RSpec.describe HealthCheckServer do
        let(:runner) { double(healthy?: true) }
        subject(:server) { described_class.new(runner, test_logger) }

        describe '#run_in_background' do
          it 'returns 200 code when runner is healthy' do
            with_server do
              expect(server_response.code).to eql('200')
            end
          end

          it 'returns 503 code when runner is unhealthy' do
            allow(runner).to receive(:healthy?).and_return(false)

            with_server do
              expect(server_response.code).to eql('503')
            end
          end

          it 'calls the :on_shutdown handler' do
            on_shutdown = double(call: true)

            prom = server.run_in_background(on_shutdown: on_shutdown)
            wait_for_server
            server.shutdown
            prom.value

            expect(on_shutdown).to have_received(:call)
          end
        end

        def with_server
          server.run_in_background
          wait_for_server
          yield
        ensure
          server.shutdown
        end

        def wait_for_server
          tries = 0
          loop do
            sleep 0.2
            break if port_open?
            raise 'server did not start' if tries > 10
            tries += 1
          end
        end

        def port_open?
          Socket.tcp('localhost', 8080, connect_timeout: 1) && true
        rescue StandardError
          false
        end

        def server_response
          Net::HTTP.get_response(URI.parse('http://localhost:8080'))
        end
      end
    end
  end
end
