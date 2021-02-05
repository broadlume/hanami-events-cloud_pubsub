# frozen_string_literal: true

require 'hanami/cli'
require 'hanami/events/cloud_pubsub'
require 'hanami/events/cloud_pubsub/health_check_server'

module Hanami
  module Events
    module CloudPubsub
      module CLI
        # CLI Commands
        module Commands
          extend Hanami::CLI::Registry

          # Command to run the worker
          class Run < Hanami::CLI::Command
            attr_reader :runner

            def initialize(*args)
              super
              @event_queue = Queue.new
            end

            option :emulator,
                   type: :boolean,
                   default: false,
                   desc: 'Whether to use the Cloud Pub/Sub emulator'

            option :config,
                   type: :string,
                   default: './config/boot.rb',
                   desc: 'Config file which is loaded before starting the runner'

            def call(opts)
              setup_env(opts)
              parse_opts(opts)
              load_config
              build_runner
              load_subscriptions
              setup_signal_handlers
              start_runner
              start_server
              sleep_forever
            end

            private

            def load_subscriptions
              CloudPubsub.subscriptions_loader.call
            end

            def setup_env(opts)
              Process.setproctitle('hanami-events-cloud_pubsub')
              ENV['PUBSUB_EMULATOR_HOST'] ||= 'localhost:8085' if opts[:emulator]
            end

            def start_server
              server = HealthCheckServer.new(runner, logger)
              on_shutdown = proc { @event_queue << proc { shutdown } }
              server.run_in_background(on_shutdown: on_shutdown)
              server
            end

            def sleep_forever
              until finished_shutting_down?
                event = @event_queue.pop
                event.call
              end
            end

            def load_config
              load String(@config)
            rescue LoadError
              logger.warn "No config file found (tried #{@config}), using default"
            end

            def start_runner
              logger.debug 'Running in emulator mode' if @emulator
              logger.info "Starting worker (pid: #{Process.pid})"
              runner.start
            end

            def parse_opts(opts)
              @emulator = opts[:emulator]
              @config = opts[:config]
            end

            def build_runner
              Hanami::Components.resolve 'events'
              events = Hanami::Components['events']
              @runner = Runner.new(logger: logger, adapter: events.adapter)
            end

            def logger
              CloudPubsub.logger
            end

            def setup_signal_handlers
              Signal.trap('TTIN') { @event_queue << method(:print_debug_info) }
              Signal.trap('INT')  { @event_queue << method(:shutdown) }
              Signal.trap('TERM') { @event_queue << method(:shutdown) }
              Signal.trap('TSTP') { @event_queue << runner.method(:shutdown) }
            end

            def shutdown
              $stdout.flush
              $stderr.flush
              runner.gracefully_shutdown
            ensure
              @finished_shutting_down = true
            end

            def finished_shutting_down?
              @finished_shutting_down == true
            end

            def print_debug_info
              warn(runner.debug_info)
            end
          end

          Commands.register 'run', Run
        end
      end
    end
  end
end
