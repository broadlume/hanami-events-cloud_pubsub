# frozen_string_literal: true

Hanami::Events::CloudPubsub.configure do |config|
  config.subscriber.streams = 2
  config.subscriber.threads.push = 2
  config.subscriber.threads.callback = 2
  config.auto_retry.enabled = true
  config.auto_retry.dead_letter_topic_name = 'my-dead-letter-topic-name'

  config.subscriptions_loader = -> do
    $events.subscribe('user.deleted', id: 'testing-2') do |payload|
      puts "Deleted2 user: #{payload}"
    end
  end
end
