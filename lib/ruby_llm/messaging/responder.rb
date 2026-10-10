# frozen_string_literal: true

module RubyLLM
  module Messaging
    # Answers one incoming message: runs the hooks, streams the model's reply
    # back through the adapter and reports failures.
    class Responder
      def initialize(config:, store:)
        @config = config
        @store = store
      end

      # @param adapter [Adapters::Base]
      # @return [String, nil] the reply text, or +nil+ when no reply was sent
      def call(adapter)
        incoming = adapter.incoming
        text = prompt_for(incoming)
        return if text.nil? || text.empty?

        reply = stream_reply(adapter, incoming, text)
        @config.after_reply&.call(reply, incoming)
        reply
      rescue StandardError => e
        handle_error(adapter, incoming, e)
        nil
      end

      private

      def prompt_for(incoming)
        return incoming.text unless @config.before_ask

        result = @config.before_ask.call(incoming)
        return nil if result == false

        result.is_a?(String) ? result : incoming.text
      end

      def stream_reply(adapter, incoming, text)
        start_typing(adapter)
        conversation = Conversation.new(key: incoming.conversation_key, store: @store, config: @config)
        reply = nil
        adapter.stream(placeholder: @config.placeholder) do |sink|
          reply = conversation.ask(text) { |chunk| sink << chunk }
        end
        reply
      end

      # A missing typing indicator must not stop the reply.
      def start_typing(adapter)
        adapter.start_typing
      rescue StandardError
        nil
      end

      def handle_error(adapter, incoming, error)
        begin
          adapter.post(@config.error_message) if @config.error_message
        rescue StandardError
          nil
        end
        raise error unless @config.on_error

        @config.on_error.call(error, incoming)
      end
    end
  end
end
