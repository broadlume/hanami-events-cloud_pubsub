# frozen_string_literal: true

require 'rack'

module Hanami
  module Events
    module CloudPubsub
      # Simple server for health checks
      class HealthCheckServer
        def initialize(runner, logger)
          @runner = runner
          @logger = logger
        end

        def start
          @logger.info 'Starting healthcheck server on port 0.0.0.0:8080'
          server.start
        end

        def run_in_background(on_shutdown:)
          log_error = proc { |err| logger.error(err.message) }

          Concurrent::Promise.execute(on_reject: log_error) do
            server.start
            on_shutdown.call(server)
          end
        end

        private

        def server
          @server ||= Rack::Server.new(
            Port: 8080,
            Host: '0.0.0.0',
            quiet: true,
            app: app
          )
        end

        def app
          health_endpoint = method(:health_endpoint)

          Rack::Builder.app do
            run health_endpoint
          end
        end

        def health_endpoint(_env)
          status = @runner.healthy? ? 200 : 503
          headers = { 'Content-Type' => 'text/html' }
          body = [status.to_s]

          [status, headers, body]
        end
      end
    end
  end
end
