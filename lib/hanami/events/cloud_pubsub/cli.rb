# frozen_string_literal: true

require 'hanami/cli'
require 'hanami/events/cloud_pubsub'

module Hanami
  module Events
    module CloudPubsub
      module CLI
        # CLI Commands
        module Commands
          extend Hanami::CLI::Registry

          # Command to run the worker
          class Run < Hanami::CLI::Command
            option :emulator,
                   type: :boolean,
                   default: false,
                   desc: 'Whether to use the Cloud Pub/Sub emulator'

            option :config,
                   type: :string,
                   default: './config/cloudpubsub.rb',
                   desc: 'Config file which is loaded before starting the runner'

            def call(opts)
              setup_env(opts)
              parse_opts(opts)
              load_config
              build_runner
              load_subscriptions
              setup_signal_handlers
              start_runner
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

            def sleep_forever
              thread = Thread.new do
                loop do
                  event = @queue.pop
                  event.call
                end
              end

              sleep
            rescue Interrupt
              thread.kill
              shutdown
            end

            def load_config
              load String(@config)
            rescue LoadError
              logger.warn "No config file found (tried #{@config}), using default"
            end

            def start_runner
              logger.debug 'Running in emulator mode' if @emulator
              logger.info "Starting worker (pid: #{Process.pid})"
              @runner.start
            end

            def parse_opts(opts)
              @emulator = opts[:emulator]
              @config = opts[:config]
            end

            def build_runner
              pubsub_opts = {}

              pubsub_opts[:project_id] = 'emulator' if @emulator

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
              @queue = Queue.new

              Signal.trap('TSTP') do
                @queue << proc { @runner.pause }
              end

              Signal.trap('CONT') do
                @queue << proc { @runner.start }
              end

              Signal.trap('TTIN') do
                @queue << proc { @runner.print_debug_info }
              end
            end

            def shutdown
              STDOUT.flush
              @runner.gracefully_shutdown
            end
          end

          Commands.register 'run', Run
        end
      end
    end
  end
end
