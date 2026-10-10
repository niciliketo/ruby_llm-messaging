# frozen_string_literal: true

module RubyLLM
  module Messaging
    # One conversation in a messaging app, backed by a fresh RubyLLM::Chat per reply.
    # Only user and assistant text is stored, so history stays small and JSON-safe.
    # Tool calls made during a reply are not kept between replies.
    class Conversation
      attr_reader :key

      def initialize(key:, store:, config:)
        @key = key
        @store = store
        @config = config
      end

      def history
        @store.load(key)
      end

      # Asks the model and yields each streamed text chunk.
      # @return [String] the full reply text
      def ask(text)
        previous = history
        chat = build_chat(previous)
        reply = chat.ask(text) do |chunk|
          yield chunk.content if block_given? && chunk.content && !chunk.content.empty?
        end
        reply_text = reply.content.to_s
        save(previous, text, reply_text)
        reply_text
      end

      def clear
        @store.clear(key) if @store.respond_to?(:clear)
      end

      private

      def build_chat(previous)
        chat = @config.chat_factory.call(@config)
        chat.with_instructions(@config.instructions) if @config.instructions
        chat.with_tools(*@config.tools) if @config.tools&.any?
        previous.each { |message| chat.add_message(role: message["role"].to_sym, content: message["content"]) }
        chat
      end

      def save(previous, text, reply_text)
        messages = previous + [
          { "role" => "user", "content" => text },
          { "role" => "assistant", "content" => reply_text }
        ]
        @store.save(key, messages.last(@config.max_history))
      end
    end
  end
end
