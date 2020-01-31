# frozen_string_literal: true

require 'hanami/events/cloud_pubsub/thread_inspector'

module Hanami
  module Events
    module CloudPubsub
      # Responsible for starting and managing the work processes
      class Runner
        attr_reader :logger, :adapter

        def initialize(adapter:, logger:, sleep_time: 2)
          @logger = logger
          @adapter = adapter
          @sleep_time = sleep_time
        end

        # Called to start the runner (subscribes to topics/etc)
        def start(_options = {})
          logger.info 'Starting CloudPubsub listeners'
          adapter.listeners.map(&:start)
          self
        end

        # Will be called on TSTP
        #
        # Stop processing new events (unsubscribe from topics, etc)
        def stop
          logger.info 'Stopping CloudPubsub listeners'
          adapter.listeners.each(&:stop)
          self
        end

        # Will be called on SIGINT, TERM
        #
        # Responsible for gracefully shutting down the runner. This may involve
        # waiting for messages to finish processing, etc. If this method succesfully
        # runs, there should be no potential for undefined behavior.
        def gracefully_shutdown
          stop
          logger.info "Gracefully shutting down CloudPubsub runner: #{self}"
          sleep_for_a_bit
          adapter.flush_messages
          adapter.listeners.each(&:wait)
          handle_on_shutdown

          self
        end

        # (optional) Kill all subscribers
        #
        # If a gracefully_shutdown times out or fails, this method will be called.
        # It is a last ditch effort to salvage resources and is used as a "damage
        # control" mechanism.
        #
        # Should we provide a mechanism to report what caused a forced shutdown?
        def force_shutdown!; end

        # Is the runner ready to start processing events?
        #
        # Starting the runner may be asyncronous (spawning threads, etc)
        # Instead of making `start` blocking, expose a way to probe for readiness
        # After this check occurs, `healthy?` will be honored.
        #
        # This pattern is similar to Kubernete's healthiness and readniess probes
        # and is much more useful than only having a `healthy?` check
        #
        # See: https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-probes/
        def ready?
          adapter.listeners.all?(&:started?)
        end

        # Is the runner healthy enough to keep going?
        #
        # Indicated whether or not the runner is healthy, useful for determing
        # whether or not the process should be restarted
        def healthy?
          ready?
        end

        # Print out some useful debugging information
        #
        # Called on TTIN to inspect the state of the runner in a terminal friendly
        # output. This provides a simple debugging if the runner gets stuck for
        # some reason.
        #
        # See: https://github.com/mperham/sidekiq/blob/e447dae961ebc894f12848d9f33446a07ffc67dc/bin/sidekiqload#L74
        # rubocop:disable Metrics/AbcSize
        def debug_info
          <<~MSG
            ╔══════ BACKTRACES
            #{Thread.list.flat_map { |thr| ThreadInspector.new(thr).to_s }.join("\n")}
            ╠══════ LISTENERS
            #{adapter.listeners.map { |lis| '║ ' + lis.format }.join("\n")}
            ║
            ╠══════ GENERAL
            ║ ready?: #{ready?}
            ║ healthy?: #{healthy?}
            ║ threads: #{Thread.list.count}
            ║ threads running: #{Thread.list.select { |thread| thread.status == 'run' }.count}
            ╚══════
          MSG
        end
        # rubocop:enable Metrics/AbcSize

        def sleep_for_a_bit
          sleep @sleep_time
        end

        def handle_on_shutdown
          return if CloudPubsub.on_shutdown_handlers.empty?

          logger.info('Calling custom on_shutdown handler')

          CloudPubsub.on_shutdown_handlers.each do |handler|
            begin
              handler.call(adapter)
            rescue StandardError => e
              logger.warn("Shutdown handler failed (#{e.message})")
            end
          end
        end
      end
    end
  end
end
