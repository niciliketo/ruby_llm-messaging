# frozen_string_literal: true

module RubyLLM
  module Messaging
    # A platform-neutral view of a message sent to the bot.
    #
    # +reference+ is a Hash that identifies the conversation, so a reply can be sent
    # later from another process with Bot#outbound. It is safe to store as JSON.
    # +raw+ holds the platform's own message object for anything not covered here.
    Incoming = Data.define(:text, :author_id, :author_name, :platform, :conversation_key, :reference, :raw) do
      def initialize(reference: {}, **fields)
        super(reference: reference.freeze, **fields)
      end
    end
  end
end
