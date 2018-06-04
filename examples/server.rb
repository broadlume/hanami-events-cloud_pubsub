# frozen_string_literal: true

ENV['PUBSUB_EMULATOR_HOST'] ||= 'localhost:8085'

require 'bundler/setup'
require 'google/cloud/pubsub'
require 'hanami/events'
require 'hanami/events/cloud_pubsub'

Hanami::Events::CloudPubsub.setup

logger = Logger.new(STDOUT).tap { |lgr| lgr.level = Logger::INFO }
pubsub = Google::Cloud::Pubsub.new project_id: 'example'
events = Hanami::Events.initialize(:cloud_pubsub, pubsub: pubsub, logger: logger)
runner = Hanami::Events::CloudPubsub::Runner.new(
  logger: logger,
  adapter: events.adapter
)

queue = Queue.new

runner.events.subscribe('user.deleted') { |payload| queue << "Deleted user: #{payload}" }
runner.events.subscribe('user.created') { |payload| queue << "Created user: #{payload}" }
logger.info "Starting CloudPubsub runner (pid: #{Process.pid})"
runner.start

Signal.trap('TSTP') do
  Thread.new { runner.pause }
end

Signal.trap('CONT') do
  Thread.new { runner.start }
end

Signal.trap('TTIN') do
  Thread.new { runner.print_debug_info }
end

loop do
  begin
    puts queue.pop
  rescue Interrupt
    STDOUT.flush
    runner.gracefully_shutdown
    break
  end
end
