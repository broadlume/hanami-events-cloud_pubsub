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
                   default: './config/cloudpubsub.rb',
                   desc: 'Config file which is loaded before starting the runner'

            option :project_id,
                   type: :string,
                   desc: 'Project ID for the project'

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
              ENV['PUBSUB_EMULATOR_HOST'] ||= 'localhost:8085' if opts[:emulator]
              CloudPubsub.setup
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
              @project_id = opts[:project_id]
              @emulator = opts[:emulator]
              @config = opts[:config]
            end

            def build_runner
              pubsub_opts = {}

              pubsub_opts[:project_id] = 'emulator' if @emulator
              pubsub_opts[:project_id] = @project_id if @project_id

              pubsub = Google::Cloud::Pubsub.new pubsub_opts
              $events = Hanami::Events.initialize(:cloud_pubsub,
                                                  pubsub: pubsub,
                                                  logger: logger,
                                                  listen: true)
              @runner = Runner.new(logger: logger, adapter: $events.adapter)
            end

            def logger
              CloudPubsub.logger
            end

            def setup_signal_handlers
              Signal.trap('TSTP') { @event_queue << runner.method(:pause) }
              Signal.trap('TTIN') { @event_queue << runner.method(:print_debug_info) }
              Signal.trap('INT')  { @event_queue << method(:shutdown) }
            end

            def shutdown
              STDOUT.flush
              runner.gracefully_shutdown
            ensure
              @finished_shutting_down = true
            end

            def finished_shutting_down?
              @finished_shutting_down == true
            end
          end

          Commands.register 'run', Run
        end
      end
    end
  end
end
