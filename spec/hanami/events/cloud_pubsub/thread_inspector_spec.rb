# frozen_string_literal: true

module Hanami
  module Events
    module CloudPubsub
      RSpec.describe ThreadInspector do
        subject { described_class.new(Thread.current) }

        describe '#to_s' do
          it 'prints a pretty version of the thread' do
            expect(subject.to_s).to start_with '║ #<Thread'
          end
        end
      end
    end
  end
end
