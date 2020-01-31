# Hanami Events for Google Cloud Pub/sub
[![Build Status](https://travis-ci.org/adHawk/hanami-events-cloud_pubsub.svg?branch=master)](https://travis-ci.org/adHawk/hanami-events-cloud_pubsub) [![Maintainability](https://api.codeclimate.com/v1/badges/7341f70d4ed1d0bd7a5d/maintainability)](https://codeclimate.com/github/adHawk/hanami-events-cloud_pubsub/maintainability) [![Test Coverage](https://api.codeclimate.com/v1/badges/7341f70d4ed1d0bd7a5d/test_coverage)](https://codeclimate.com/github/adHawk/hanami-events-cloud_pubsub/test_coverage)

## Installation

```ruby
bundle add hanami-events-cloud_pubsub
```

If using Hanami, register the adapter in your `config/environment.rb`:

```ruby
# config/environment.rb
# ...
require_relative './../lib/my_app'
require_relative './../apps/web/application'
# ...

require 'hanami/events/cloud_pubsub/register' # <----
```

Configure the pubsub adapter how you want (optional):

```ruby
# config/environment.rb

Hanami.configure do
  environment :development do
    cloud_pubsub do |config|
      config.pubsub = { project_id: 'emulator' } # optional
      config.logger = Hanami.logger # optional
      config.namespace = :staging # optional
      config.auto_create_topics = false # optional
      config.auto_create_subscriptions = false # optional
      config.on_shutdown = ->(adapter) { Analytics.flush } # optional
      config.error_handlers << ->(err, message) { MyErrorReporter.report(err) }
      # ...
    end
  end
end
```

## Usage

This gem is compatible with the
[hanami-events](https://github.com/hanami/events) gem, with a couple caveats:

1. All subscribers must specify an `id:` attribute. When you subscribe, you
should pass this:

```ruby
Hanami.events.subscribe('user.deleted', id: 'my-subscriber-id') do |payload|
  puts "Deleted user: #{payload}"
end
```

Additional options will be passed to `Google::Cloud::Pubsub::Subscription#listen`:
```ruby
Hanami.events.subscribe('foo', id: 'bar', deadline: 30) do |payload|
  sleep 29 # message will finish before deadline
end
```

2. Responding to events is done in a different process via the CLI.

First, create a config file:

```ruby
# config/cloudpubsub.rb

require 'config/environment'

Hanami.boot

class CustomMiddleware
  def call(message)
    puts 'Middleware started!'
    yield
    puts 'Middleware ended!'
  end
end

Hanami::Events::CloudPubsub.configure do |config|
  # required
  config.subscriptions_loader = -> do
    # Ensure these files are not loaded until *after* the subscriptions are
    # setup, or else you will have an undefined reference to `$events`
    Hanami::Utils.require! 'apps/web/subscriptions'
  end

  # (optional)
  config.logger = Hanami.logger

  # (optional)
  config.error_handlers << lambda do |err, message|
    Honeybadger.notify(err, context: message.attributes)
  end

  config.middleware << CustomMiddleware.new # must respond to #call
end
```

Then, run the worker process:

```sh
bundle exec cloudpubsub run
```

# Testing

If you would like to use an emulator process for testing:

```sh
$(gcloud beta emulators pubsub env-init)
gcloud beta emulators pubsub start
bundle exec cloudpubsub run --emulator
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run
`rake spec` to run the tests. You can also run `bin/console` for an interactive
prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To
release a new version, update the version number in `version.rb`, and then run
`bundle exec rake release`, which will create a git tag for the version, push
git commits and tags, and push the `.gem` file to
[rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at
https://github.com/ianks/hanami-events-cloud_pubsub. This project is intended
to be a safe, welcoming space for collaboration, and contributors are expected
to adhere to the [Contributor Covenant](http://contributor-covenant.org) code
of conduct.

## License

The gem is available as open source under the terms of the [MIT
License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Hanami::Events::CloudPubsub project’s codebases,
issue trackers, chat rooms and mailing lists is expected to follow the [code of
conduct](https://github.com/ianks/hanami-events-cloud_pubsub/blob/master/CODE_OF_CONDUCT.md).
