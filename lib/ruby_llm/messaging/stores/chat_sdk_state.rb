# frozen_string_literal: true

require "json"

module RubyLLM
  module Messaging
    module Stores
      # Keeps history in a ChatSDK state backend (memory, Redis, Postgres or MySQL),
      # so it lives wherever the bot already keeps its thread subscriptions.
      class ChatSDKState
        KEY_PREFIX = "ruby_llm-messaging:history:"
        DEFAULT_TTL = 30 * 24 * 3600

        def initialize(state, ttl: DEFAULT_TTL)
          @state = state
          @ttl = ttl
        end

        def load(key)
          raw = @state.get(KEY_PREFIX + key)
          raw ? JSON.parse(raw) : []
        end

        def save(key, messages)
          @state.set(KEY_PREFIX + key, JSON.generate(messages), ttl: @ttl)
        end

        def clear(key)
          @state.delete(KEY_PREFIX + key)
        end
      end
    end
  end
end
