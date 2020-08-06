# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'hanami/events/cloud_pubsub/version'

Gem::Specification.new do |spec|
  spec.name          = 'hanami-events-cloud_pubsub'
  spec.version       = Hanami::Events::CloudPubsub::VERSION
  spec.authors       = ['Ian Ker-Seymer']
  spec.email         = ['i.kerseymer@gmail.com']

  spec.summary       = 'Google Cloud Pub/Sub adapter for the hanami-events gem'
  spec.description   = 'Makes it easy to use Cloud Pub/Sub with Hanami'
  spec.homepage      = 'https://github.com/adHawk/hanami-events-cloud_pubsub'
  spec.license       = 'MIT'

  spec.files = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'dry-configurable', '>= 0.8'
  spec.add_dependency 'google-cloud-pubsub', '>= 0.38.1', '< 1.11'
  spec.add_dependency 'hanami-cli', '~> 0.2'
  spec.add_dependency 'hanami-events', '~> 0.2.0'
  spec.add_dependency 'rack'

  spec.add_development_dependency 'bundler', '~> 1.16'
  spec.add_development_dependency 'prometheus-client'
  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'rspec', '~> 3.0'
end
