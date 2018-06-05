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
              CloudPubsub.setup
              parse_opts(opts)
              setup_signal_handlers
              build_runner
              load_config
              start_runner
              sleep_forever
            rescue Interrupt
              shutdown
            end

            private

            def sleep_forever
              sleep
            end

            def load_config
              load @config
            end

            def start_runner
              logger.info "Starting CloudPubsub runner (pid: #{Process.pid})"
              @runner.start
            end

            def parse_opts(opts)
              @emulator = opts[:emulator]
              logger.info 'Running if emulator mode' if @emulator
              @config = opts[:config]
              logger.debug "Using config file: #{@config}"
            end

            def build_runner
              pubsub_opts = {}

              ENV['PUBSUB_EMULATOR_HOST'] ||= 'localhost:8085' if @emulator
              pubsub_opts[:project_id] = 'emulator' if @emulator

              pubsub = Google::Cloud::Pubsub.new pubsub_opts
              $events = Hanami::Events.initialize(:cloud_pubsub,
                                                  pubsub: pubsub,
                                                  logger: logger,
                                                  listen: true)
              @runner = Runner.new(logger: logger, adapter: $events.adapter)
            end

            def logger
              if defined?(Hanami.logger)
                Hanami.logger
              else
                Logger.new(STDOUT).tap { |logger| logger.level = Logger::INFO }
              end
            end

            def setup_signal_handlers
              Signal.trap('TSTP') do
                Thread.new { @runner.pause }
              end

              Signal.trap('CONT') do
                Thread.new { @runner.start }
              end

              Signal.trap('TTIN') do
                Thread.new { @runner.print_debug_info }
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
