# frozen_string_literal: true

require 'webrick'

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
          logger.info 'Starting healthcheck server on port 0.0.0.0:8081'
          start_server
        end

        def shutdown
          logger.info 'Shutting down healthcheck server'
          @server.shutdown
        end

        def run_in_background(on_shutdown: nil)
          prom = Concurrent::Promise.execute do
            start
            on_shutdown&.call(@server)
          end

          prom.catch { |err| logger.error(err) }
        end

        private

        attr_reader :logger, :runner

        def start_server
          require 'rack'

          Rack::Handler::WEBrick.run(
            rack_app,
            AccessLog: [],
            Host: '0.0.0.0',
            Port: 8081,
            Logger: WEBrick::Log.new('/dev/null')
          ) do |server|
            @server = server
          end
        end

        def rack_app
          health_endpoint_app = method(:health_endpoint)

          Rack::Builder.new do |builder|
            builder.use Rack::Deflater
            if defined?(::Prometheus::Client)
              require 'prometheus/middleware/exporter'
              builder.use ::Prometheus::Middleware::Exporter
            end
            builder.run health_endpoint_app
          end
        end

        def health_endpoint(_env)
          headers = { 'Content-Type' => 'text/plain' }
          status = runner.healthy? ? 200 : 503
          body = [runner.debug_info]
          [status, headers, body]
        end
      end
    end
  end
end
