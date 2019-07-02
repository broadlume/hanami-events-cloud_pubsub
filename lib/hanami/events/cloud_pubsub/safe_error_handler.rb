# frozen_string_literal: true

module Hanami
  module Events
    module CloudPubsub
      # Safely run error_handlers
      module SafeErrorHandler
        def self.call(handler, err, message)
          handler.call(err, message)
        rescue StandardError => e
          CloudPubsub.logger.error '!!! ERROR HANDLER THREW AN ERROR !!!'
          CloudPubsub.logger.error e
          CloudPubsub.logger.error e.backtrace.join("\n") unless e.backtrace.nil?
        end
      end
    end
  end
end
