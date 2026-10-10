# Writing an adapter

The `Responder` talks to platforms only through `RubyLLM::Messaging::Adapters::Base`. An adapter instance wraps one incoming message and the conversation it arrived in.

## Use a ChatSDK adapter first

ChatSDK already supports Slack, Teams, Google Chat, Mattermost, Discord, Telegram, Twilio, Messenger, WhatsApp, X and Linear. For these, add the ChatSDK adapter gem to `Bot.new(adapters:)`. You do not need new code:

```ruby
require "chat_sdk/slack"
require "chat_sdk/whatsapp"

bot = RubyLLM::Messaging::Bot.new(
  user_name: "assistant",
  adapters: {
    teams: ChatSDK::Teams::Adapter.new,
    slack: ChatSDK::Slack::Adapter.new(bot_token: ENV["SLACK_BOT_TOKEN"], signing_secret: ENV["SLACK_SIGNING_SECRET"]),
    whatsapp: ChatSDK::WhatsApp::Adapter.new
  },
  state: ChatSDK::State::Redis.new(url: ENV["REDIS_URL"])
)
```

Each platform gets its own history, because the conversation key starts with the adapter name.

## The contract

| Method | Required | Purpose |
|---|---|---|
| `incoming` | Yes | Returns a `RubyLLM::Messaging::Incoming`. `conversation_key` must be unique per conversation and stable between messages. |
| `post(text)` | Yes | Posts a new message to the conversation. |
| `stream(placeholder:) { \|sink\| }` | No | Yields an object that accepts `sink << chunk`. The default collects the chunks and calls `post` once. |
| `start_typing` | No | Shows a typing indicator. The default does nothing. |

## Example: a platform outside ChatSDK

```ruby
class MyChatAdapter < RubyLLM::Messaging::Adapters::Base
  def initialize(client, payload)
    super()
    @client = client
    @payload = payload
  end

  def incoming
    RubyLLM::Messaging::Incoming.new(
      text: @payload["text"],
      author_id: @payload["user_id"],
      author_name: @payload["user_name"],
      platform: :my_chat,
      conversation_key: "my_chat:#{@payload['room_id']}",
      raw: @payload
    )
  end

  def post(text)
    @client.send_message(room: @payload["room_id"], text: text)
  end
end

responder = RubyLLM::Messaging::Responder.new(
  config: RubyLLM::Messaging.configuration,
  store: RubyLLM::Messaging::Stores::Memory.new   # use a shared store in production
)

# In your webhook handler, after you verify the request:
responder.call(MyChatAdapter.new(client, payload))
```

Add `stream` when the platform can edit messages. That gives users the same live reply they get in Teams.
