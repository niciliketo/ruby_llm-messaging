# frozen_string_literal: true

module RubyLLM
  module Messaging
    # A platform-neutral view of a message sent to the bot.
    # +raw+ holds the platform's own message object for anything not covered here.
    Incoming = Data.define(:text, :author_id, :author_name, :platform, :conversation_key, :raw)
  end
end
