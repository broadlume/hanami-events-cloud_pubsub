# frozen_string_literal: true

source 'https://rubygems.org'

git_source(:github) { |repo_name| "https://github.com/#{repo_name}" }

# Specify your gem's dependencies in hanami-events-cloud_pubsub.gemspec
gemspec

RUBY_MAJOR = RUBY_VERSION[0].to_i

gem 'hanami-events', github: 'hanami/events'
gem 'pry'
gem 'rubocop'
gem 'simplecov', require: false
gem 'request_id', '~> 0.4.3'
gem 'webrick' if RUBY_MAJOR > 2
