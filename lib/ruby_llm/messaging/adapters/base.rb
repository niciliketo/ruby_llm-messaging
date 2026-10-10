# frozen_string_literal: true

module RubyLLM
  module Messaging
    module Adapters
      # The contract between the Responder and a messaging platform.
      # One instance wraps one incoming message and the conversation it arrived in.
      #
      # A new platform needs a subclass that implements #incoming and #post.
      # Override #stream and #start_typing when the platform supports them.
      class Base
        # @return [RubyLLM::Messaging::Incoming]
        def incoming
          raise NotImplementedError, "#{self.class} must implement #incoming"
        end

        # Posts +text+ as a new message in the conversation.
        def post(text)
          raise NotImplementedError, "#{self.class} must implement #post"
        end

        # Yields a sink that accepts text chunks with <<. The default collects
        # every chunk and posts once, for platforms that cannot edit messages.
        def stream(placeholder: nil) # rubocop:disable Lint/UnusedMethodArgument
          buffer = +""
          yield buffer
          post(buffer) unless buffer.empty?
        end

        # Shows a typing indicator where the platform supports one.
        def start_typing; end
      end
    end
  end
end
