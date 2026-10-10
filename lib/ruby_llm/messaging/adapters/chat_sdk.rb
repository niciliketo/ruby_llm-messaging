# frozen_string_literal: true

module RubyLLM
  module Messaging
    module Adapters
      # Wraps a ChatSDK thread and message, so every ChatSDK platform adapter
      # (Teams, Slack, WhatsApp, ...) works without platform-specific code here.
      class ChatSDK < Base
        # Mention markup that platforms leave in the message text:
        # Teams "<at>Bot</at>", Slack "<@U123>", Discord "<@123>" and "<@!123>".
        MENTION_PATTERN = %r{<at>[^<]*</at>|<@!?[A-Z0-9]+>}i

        attr_reader :thread, :message

        def initialize(thread, message)
          super()
          @thread = thread
          @message = message
        end

        def incoming
          @incoming ||= Incoming.new(
            text: clean_text(message.text),
            author_id: message.author&.id,
            author_name: message.author&.name,
            platform: message.platform,
            conversation_key: conversation_key,
            reference: reference,
            raw: message
          )
        end

        def post(text)
          thread.post(text)
        end

        # ChatSDK posts the placeholder, then edits it on a throttle as chunks arrive.
        # It falls back to a single post on platforms that cannot edit messages.
        def stream(placeholder: nil, &)
          thread.post_stream(placeholder: placeholder, &)
        end

        def start_typing
          return unless thread.adapter.supports?(:typing_indicator)

          thread.adapter.start_typing(channel_id: thread.channel_id, thread_id: thread.id)
        end

        # Identifies the conversation for Bot#outbound. Teams fields are added when the
        # platform sends them: the service URL replies must go to, the Microsoft Entra
        # tenant, the conversation type ("personal", "groupChat", "channel") and the
        # author's Entra object id.
        def reference
          { platform: thread.adapter.name, channel_id: thread.channel_id, thread_id: thread.id }
            .merge(teams_reference(message.raw.is_a?(Hash) ? message.raw : {}))
        end

        private

        def conversation_key
          "#{thread.adapter.name}:#{thread.channel_id}:#{thread.id}"
        end

        def teams_reference(activity)
          {
            service_url: activity["serviceUrl"],
            tenant_id: activity.dig("conversation", "tenantId") || activity.dig("channelData", "tenant", "id"),
            conversation_type: activity.dig("conversation", "conversationType"),
            author_platform_id: activity.dig("from", "aadObjectId")
          }.compact
        end

        def clean_text(text)
          text.to_s.gsub(MENTION_PATTERN, "").gsub(/[ \t]{2,}/, " ").strip
        end
      end
    end
  end
end
