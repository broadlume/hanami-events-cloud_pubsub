# frozen_string_literal: true

RSpec.describe Hanami::Events::CloudPubsub do
  it 'has a version number' do
    expect(Hanami::Events::CloudPubsub::VERSION).not_to be nil
  end
end
