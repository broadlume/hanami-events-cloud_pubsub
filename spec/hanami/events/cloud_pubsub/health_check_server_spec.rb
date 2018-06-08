# frozen_string_literal: true

require_relative './../../../../lib/hanami/events/cloud_pubsub/health_check_server'

module Hanami
  module Events
    module CloudPubsub
      RSpec.describe HealthCheckServer do
        let(:runner) { double(healthy?: true) }
        subject(:server) { described_class.new(runner, test_logger) }

        describe '#start' do
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
        end

        describe '#run_in_background' do
          it 'calls the :on_shutdown handler' do
            on_shutdown = double(call: true)

            prom = server.run_in_background(on_shutdown: on_shutdown)
            wait_for_server
            parent_pid = Process.pid
            fork { Process.kill 'INT', parent_pid }
            prom.value

            expect(on_shutdown).to have_received(:call)
          end
        end

        def with_server
          pid = fork { server.start }
          wait_for_server
          yield
        ensure
          Process.kill 'INT', pid
        end

        def wait_for_server
          loop { break if port_open? }
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
