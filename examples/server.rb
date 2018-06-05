# frozen_string_literal: true

# To run this server:
# bundle exec exe/cloudpubsub run --emulator --config examples/server.rb

$events.adapter.subscribe('user.deleted', id: 'testing-1') do |payload|
  puts "Deleted user: #{payload}"
end

$events.adapter.subscribe('user.deleted', id: 'testing-2') do |payload|
  puts "Deleted2 user: #{payload}"
end
