# frozen_string_literal: true

RSpec.describe Hanami::Events::CloudPubsub::Mixin do
  context 'when included into class' do
    let(:event_bus) { Hanami::Events.new(:memory_sync) }

    subject(:dummy_handler) do
      Class.new do
        include Hanami::Events::CloudPubsub::Mixin

        def call(payload)
          payload
        end
      end
    end

    context 'with extra arguments' do
      it 'includes extra args when calling #subscribe on the event bus' do
        id = 'dummy-handler'
        expect(event_bus).to receive(:subscribe).with(anything, id: id)

        dummy_handler.send(:subscribe_to, event_bus, 'user.created', id: id)
      end
    end
  end
end
