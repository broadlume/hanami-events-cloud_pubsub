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
          server.start
        end

        def shutdown
          logger.info 'Shutting down healthcheck server'
          server.shutdown
        end

        def run_in_background(on_shutdown: nil)
          prom = Concurrent::Promise.execute do
            start
            on_shutdown&.call(server)
          end

          prom.catch { |err| logger.error(err) }
        end

        private

        attr_reader :logger, :runner

        def server
          @server ||=
            WEBrick::HTTPServer.new(
              Port: 8081,
              BindAddress: '0.0.0.0',
              Logger: WEBrick::Log.new('/dev/null'),
              AccessLog: []
            ).tap do |srv|
              srv.mount_proc '/', method(:health_endpoint)
            end
        end

        def health_endpoint(_req, res)
          res['Content-Type'] = 'text/plain'
          res.status = runner.healthy? ? 200 : 503
          res.body = res.status.to_s
        end
      end
    end
  end
end
