# frozen_string_literal: true

module RubyLLM
  module Messaging
    module Stores
      # Keeps history in the current process. Use it for tests and local development only:
      # history is lost on restart and is not shared between processes.
      class Memory
        def initialize
          @mutex = Mutex.new
          @data = {}
        end

        # @return [Array<Hash>] messages as {"role" => ..., "content" => ...}
        def load(key)
          @mutex.synchronize { (@data[key] || []).map(&:dup) }
        end

        def save(key, messages)
          @mutex.synchronize { @data[key] = messages.map(&:dup) }
        end

        def clear(key)
          @mutex.synchronize { @data.delete(key) }
        end
      end
    end
  end
end
