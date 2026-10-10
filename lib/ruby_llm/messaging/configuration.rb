# frozen_string_literal: true

module RubyLLM
  module Messaging
    # Settings shared by every bot unless a bot is given its own Configuration.
    class Configuration
      # Model id passed to RubyLLM.chat. +nil+ uses RubyLLM's default model.
      attr_accessor :model

      # System prompt applied to every conversation.
      attr_accessor :instructions

      # RubyLLM::Tool classes or instances the model may call.
      attr_accessor :tools

      # Where conversation history lives. Must respond to #load(key) and #save(key, messages).
      # +nil+ makes a Bot use its ChatSDK state backend.
      attr_accessor :store

      # Number of user and assistant messages kept per conversation.
      attr_accessor :max_history

      # Text shown while the model works. +nil+ posts nothing until the first chunk arrives.
      attr_accessor :placeholder

      # Text posted to the conversation when a reply fails.
      attr_accessor :error_message

      # Builds the RubyLLM::Chat for each reply. Receives the Configuration.
      attr_accessor :chat_factory

      # Called with (error, incoming) after a reply fails.
      attr_accessor :on_error

      # Called with the Incoming message before the model is asked.
      # Return a String to replace the text, or +false+ to skip the reply.
      attr_accessor :before_ask

      # Called with (reply_text, incoming) after the reply is sent.
      attr_accessor :after_reply

      # Settings not set here default to +nil+.
      def initialize
        @tools = []
        @max_history = 40
        @placeholder = "Thinking..."
        @error_message = "Sorry, something went wrong while answering. Please try again."
        @chat_factory = ->(config) { RubyLLM.chat(model: config.model) }
      end
    end
  end
end
