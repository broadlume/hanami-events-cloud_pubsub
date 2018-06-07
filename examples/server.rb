# frozen_string_literal: true

# To run this server:
# bundle exec exe/cloudpubsub run --emulator --config examples/server.rb

# $events.subscribe('user.deleted', id: 'testing-1') do |payload|
#   puts "Deleted user: #{payload}"
# end

$events.subscribe('user.deleted', id: 'testing-2') do |payload|
  raise 'shit'
  puts "Deleted2 user: #{payload}"
end
