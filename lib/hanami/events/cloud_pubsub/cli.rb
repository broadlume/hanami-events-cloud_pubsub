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
                   desc: 'Whether to use an the Cloud Pub/Sub emulator'

            def call(opts)
              Hanami::Events::CloudPubsub.setup
              setup_signal_handlers
              @runner = build_runner(opts)
              logger.info "Starting CloudPubsub runner (pid: #{Process.pid})"
              @runner.start

              # sleep forevverrrr
              sleep
            rescue Interrupt
              shutdown
            end

            private

            def setup_environment; end

            def build_runner(opts)
              pubsub_opts = {}

              ENV['PUBSUB_EMULATOR_HOST'] ||= 'localhost:8085' if opts[:emulator]
              pubsub_opts[:project_id] = 'emulator' if opts[:emulator]

              pubsub = Google::Cloud::Pubsub.new pubsub_opts
              events = Hanami::Events.initialize(:cloud_pubsub, pubsub: pubsub, logger: logger)
              events.adapter.listen
              Hanami::Events::CloudPubsub::Runner.new(
                logger: logger,
                adapter: events.adapter
              )
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
