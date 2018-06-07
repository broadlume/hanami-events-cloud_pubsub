# frozen_string_literal: true

module Hanami
  module Events
    module CloudPubsub
      # Safely run error_handlers
      module SafeErrorHandler
        def self.call(handler, err, message)
          handler.call(err, message)
        rescue StandardError => ex
          CloudPubsub.logger.error '!!! ERROR HANDLER THREW AN ERROR !!!'
          CloudPubsub.logger.error ex
          CloudPubsub.logger.error ex.backtrace.join("\n") unless ex.backtrace.nil?
        end
      end
    end
  end
end
