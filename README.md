# Hanami::Events::CloudPubsub
[![Build Status](https://travis-ci.org/adHawk/hanami-events-cloud_pubsub.svg?branch=master)](https://travis-ci.org/adHawk/hanami-events-cloud_pubsub) [![Maintainability](https://api.codeclimate.com/v1/badges/7341f70d4ed1d0bd7a5d/maintainability)](https://codeclimate.com/github/adHawk/hanami-events-cloud_pubsub/maintainability)

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'hanami-events-cloud_pubsub'
```

And then execute:

    $ bundle

## Usage

This gem is compatible with the
[hanami-events](https://github.com/hanami/events) gem, with a couple caveats:

1. All subscribers must specify an `id:` attribute. When you subscribe, you
should pass this:

```ruby
$events.subscribe('user.deleted', id: 'my-subscriber-id') do |payload|
  puts "Deleted user: #{payload}"
end
```

2. If you want mixin behavior, follow this example until [this patch is
merged](https://github.com/hanami/events/pull/76)

```ruby
class WelcomeMailer
  include Hanami::Events::CloudPubsub::Mixin

  subscribe_to $events, 'user.created', id: 'welcome-mailer'

  def call(payload)
    payload
  end
end
```

3. Responding to events is done in a different process via the CLI.

First, create a config file:

```ruby
# config/cloudpubsub.rb

require 'config/environment'

Hanami.boot

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
