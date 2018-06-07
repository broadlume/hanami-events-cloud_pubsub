# frozen_string_literal: true

Hanami::Events::CloudPubsub.configure do |config|
  config.subscriptions_loader = -> do
    $events.subscribe('user.deleted', id: 'testing-2') do |payload|
      puts "Deleted2 user: #{payload}"
    end
  end
end
