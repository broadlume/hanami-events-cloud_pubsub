# frozen_string_literal: true

module Hanami
  module Events
    module CloudPubsub
      # Generate prettier backtraces for inspection
      class ThreadInspector
        attr_reader :backtrace, :thread

        def initialize(thread)
          @thread = thread
          @backtrace = thread.backtrace
        end

        def to_s
          "║ #{thread.inspect}\n" + pretty_backtrace
        end

        def inspect
          thread.inspect
        end

        private

        def pretty_backtrace
          pretty_backtrace = backtrace.map do |call|
            parts = call.match(/^(?<file>.+):(?<line>\d+):in `(?<code>.*)'$/)

            if parts
              file = parts[:file].sub(/^#{Regexp.escape(File.join(Dir.getwd, ''))}/, '')
              pretty_line(file, parts)
            else
              colorize(call, 31)
            end
          end

          join_backtrace(pretty_backtrace)
        end

        def colorize(text, color_code)
          "\e[#{color_code}m#{text}\e[0m"
        end

        def pretty_line(file, parts)
          "#{colorize(file, 36)} #{colorize('(', 37)}" \
            "#{colorize(parts[:line], 32)}#{colorize('): ', 37)} " \
            "#{colorize(parts[:code], 31)}"
        end

        def join_backtrace(pretty_backtrace)
          pretty_backtrace.map! { |line| "║\t#{line}" }
          pretty_backtrace << '║'
          pretty_backtrace.join("\n")
        end
      end
    end
  end
end
