# frozen_string_literal: true

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
      # @param chat_sdk_options [Hash] passed through to ChatSDK::Chat.new
      def initialize(user_name:, adapters:, state: ::ChatSDK::State::Memory.new,
                     config: Messaging.configuration, **chat_sdk_options)
        @config = config
        @chat_sdk = ::ChatSDK::Chat.new(user_name: user_name, adapters: adapters, state: state, **chat_sdk_options)
        @store = config.store || Stores::ChatSDKState.new(state)
        @responder = Responder.new(config: config, store: @store)
        register_handlers
      end

      # Rack endpoints, one per adapter: +bot.webhooks[:teams]+.
      def webhooks
        chat_sdk.webhooks
      end

      # Answers a ChatSDK thread and message directly, outside the webhook handlers.
      def respond(thread, message)
        @responder.call(Adapters::ChatSDK.new(thread, message))
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
