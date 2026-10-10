# frozen_string_literal: true

module RubyLLM
  module Messaging
    # Sends messages to a conversation the bot heard from earlier, for example from a
    # background job. Build one with Bot#outbound and an Incoming#reference.
    class Outbound
      # @param chat_sdk [ChatSDK::Chat]
      # @param reference [Hash] an Incoming#reference, with Symbol or String keys
      def initialize(chat_sdk, reference)
        ref = reference.to_h.transform_keys(&:to_sym)
        platform = ref.fetch(:platform).to_sym
        adapter = chat_sdk.adapter(platform)
        # Teams replies go to a per-conversation service URL that ChatSDK only learns
        # from incoming activities, so a new process must register it first.
        if ref[:service_url] && adapter.respond_to?(:register_service_url)
          adapter.register_service_url(ref.fetch(:channel_id), ref[:service_url])
        end
        @thread = chat_sdk.thread(ref.fetch(:thread_id), channel_id: ref.fetch(:channel_id), adapter_name: platform)
      end

      # @return [String, nil] the platform's id for the new message
      def post(text)
        message = @thread.post(text)
        message.respond_to?(:id) ? message.id : nil
      end

      def edit(message_id, text)
        @thread.edit(message_id, text)
      end

      def supports_edit?
        @thread.adapter.supports?(:edit_messages)
      end

      def start_typing
        return unless @thread.adapter.supports?(:typing_indicator)

        @thread.adapter.start_typing(channel_id: @thread.channel_id, thread_id: @thread.id)
      end
    end
  end
end
