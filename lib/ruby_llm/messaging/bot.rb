# frozen_string_literal: true

# ChatSDK uses Rack::Request without requiring it, so load all of Rack.
require "rack"

module RubyLLM
  module Messaging
    # A ChatSDK bot that answers with RubyLLM.
    #
    # It replies when it is mentioned and in direct messages. After a mention it
    # follows the thread and replies to every later message there.
    class Bot
      attr_reader :chat_sdk, :config, :store

      # @param adapters [Hash{Symbol => ChatSDK::Adapter::Base}] e.g. { teams: ChatSDK::Teams::Adapter.new }
      # @param state [ChatSDK::State::Base] use ChatSDK::State::Redis (or Pg/Mysql) in production
      # @param config [Configuration] defaults to RubyLLM::Messaging.configuration
      # @param handler [#call, nil] receives an Adapters::Base for each message, in place of
      #   the built-in Responder. Use it when the app produces replies itself, for example
      #   in a background job that answers through #outbound.
      # @param chat_sdk_options [Hash] passed through to ChatSDK::Chat.new
      def initialize(user_name:, adapters:, state: ::ChatSDK::State::Memory.new,
                     config: Messaging.configuration, handler: nil, **chat_sdk_options)
        @config = config
        @chat_sdk = ::ChatSDK::Chat.new(user_name: user_name, adapters: adapters, state: state, **chat_sdk_options)
        @store = config.store || Stores::ChatSDKState.new(state)
        @handler = handler || Responder.new(config: config, store: @store)
        register_handlers
      end

      # Rack endpoint for one adapter: +bot.webhooks[:teams]+.
      # ChatSDK rewinds the request body, which Rack 3 does not guarantee, so each
      # endpoint is wrapped to make the body rewindable.
      def webhooks
        @webhooks ||= Hash.new do |endpoints, name|
          endpoints[name] = ::Rack::RewindableInput::Middleware.new(chat_sdk.webhooks[name])
        end
      end

      # Answers a ChatSDK thread and message directly, outside the webhook handlers.
      def respond(thread, message)
        @handler.call(Adapters::ChatSDK.new(thread, message))
      end

      # Sends to a conversation from anywhere, given an Incoming#reference.
      # @return [Outbound]
      def outbound(reference)
        Outbound.new(chat_sdk, reference)
      end

      private

      def register_handlers
        chat_sdk.on_new_mention do |thread, message|
          thread.subscribe
          respond(thread, message)
        end
        # ChatSDK 1.1 fires this for any unmentioned message, so check the subscription here.
        chat_sdk.on_subscribed_message { |thread, message| respond(thread, message) if thread.subscribed? }
        chat_sdk.on_direct_message { |thread, message| respond(thread, message) }
      end
    end
  end
end
