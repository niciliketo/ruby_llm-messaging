# ruby_llm-messaging

Connect a [RubyLLM](https://rubyllm.com) chat to messaging apps. Microsoft Teams works today. Slack, WhatsApp and other platforms plug in as adapters.

The gem uses [ChatSDK Ruby](https://github.com/rootlyhq/chat-sdk) for the platform work: webhooks, request signatures, posting and editing messages. It adds the LLM side:

- A reply to each mention and direct message, streamed into one message that updates as text arrives.
- Conversation history per thread, kept in the same store as the bot's ChatSDK state (memory, Redis, Postgres or MySQL).
- Hooks before and after each reply, and one place to handle errors.

## Installation

```ruby
gem "ruby_llm-messaging"
gem "chat_sdk-teams"        # one gem per platform you use
gem "chat_sdk-state-redis"  # history and subscriptions that survive restarts
```

## Quick start (Microsoft Teams)

```ruby
require "ruby_llm/messaging"
require "ruby_llm/messaging/teams"
require "chat_sdk/state/redis"

RubyLLM.configure { |c| c.anthropic_api_key = ENV["ANTHROPIC_API_KEY"] }

RubyLLM::Messaging.configure do |config|
  config.model = "claude-sonnet-5-5"
  config.instructions = "You are the help desk assistant. Keep answers short."
  config.tools = [LookupOrder]   # any RubyLLM::Tool
end

teams = ChatSDK::Teams::Adapter.new   # reads TEAMS_APP_ID and TEAMS_APP_PASSWORD
RubyLLM::Messaging::Teams.single_tenant!(teams, tenant_id: ENV["TEAMS_TENANT_ID"])

bot = RubyLLM::Messaging::Bot.new(
  user_name: "helpdesk",
  adapters: { teams: teams },
  state: ChatSDK::State::Redis.new(url: ENV["REDIS_URL"])
)
```

Mount the webhook:

```ruby
# config.ru
map("/api/messages") { run bot.webhooks[:teams] }

# Rails: config/routes.rb
mount LLM_BOT.webhooks[:teams], at: "/api/messages"
```

See `examples/teams_rack/config.ru` and `examples/rails/README.md` for complete files.

`single_tenant!` is needed for Single Tenant Azure Bots, which is what Azure creates today. ChatSDK 1.1 always asks the shared `botframework.com` tenant for tokens, so without it the bot receives messages but cannot reply. Skip it for an older multi-tenant bot.

### Teams setup

1. In the Azure portal, create an **Azure Bot** resource. Note the app ID, client secret and tenant ID. Set them as `TEAMS_APP_ID`, `TEAMS_APP_PASSWORD` and `TEAMS_TENANT_ID`.
2. Set the bot's messaging endpoint to `https://<your-host>/api/messages`.
3. Turn on the **Microsoft Teams** channel for the bot.
4. Create a Teams app package (manifest) that uses the bot's app ID, then upload it to Teams.

For local work, expose port 3978 with a tunnel such as ngrok, or use the Bot Framework Emulator.

## How the bot replies

| Event | Behaviour |
|---|---|
| The bot is mentioned in a channel or group chat | It replies, then follows that thread. |
| A new message in a thread the bot follows | It replies without a mention. |
| A direct (1:1) message | It replies. |

Each reply starts with the placeholder text, then updates as the model streams. Platforms that cannot edit messages get one message at the end.

## Configuration

| Setting | Default | Purpose |
|---|---|---|
| `model` | RubyLLM default | Model id for `RubyLLM.chat`. |
| `instructions` | `nil` | System prompt for every conversation. |
| `tools` | `[]` | RubyLLM tools the model may call. |
| `max_history` | `40` | User and assistant messages kept per thread. |
| `placeholder` | `"Thinking..."` | First text shown. `nil` waits for the first chunk. |
| `error_message` | A short apology | Posted when a reply fails. `nil` posts nothing. |
| `store` | The bot's ChatSDK state | Any object with `load(key)` and `save(key, messages)`. |
| `chat_factory` | `RubyLLM.chat(model:)` | Builds the `RubyLLM::Chat`. Use it for providers, temperature, and similar settings. |
| `before_ask` | `nil` | `->(incoming) { ... }`. Return a String to change the prompt, or `false` to skip the reply. |
| `after_reply` | `nil` | `->(reply, incoming) { ... }` for logging or analytics. |
| `on_error` | `nil` | `->(error, incoming) { ... }`. Without it, errors are re-raised and ChatSDK logs them. |

`incoming` is a `RubyLLM::Messaging::Incoming` with `text`, `author_id`, `author_name`, `platform`, `conversation_key` and `raw` (the ChatSDK message).

Example: allow only users from one Teams tenant:

```ruby
config.before_ask = lambda do |incoming|
  incoming.raw.raw.dig("conversation", "tenantId") == ENV["TEAMS_TENANT_ID"] && incoming.text
end
```

Pass a separate `RubyLLM::Messaging::Configuration` to `Bot.new(config:)` to run bots with different settings in one process.

## Replying from your own code

The built-in responder answers inside the webhook request. To produce replies elsewhere, for example in a background job that uses your app's own chat history and tools, pass a `handler`. It receives an adapter for each message. Save `incoming.reference`, return quickly, and reply later with `bot.outbound`:

```ruby
bot = RubyLLM::Messaging::Bot.new(
  user_name: "assistant",
  adapters: { teams: teams },
  state: state,
  handler: ->(adapter) { AnswerJob.perform_later(adapter.incoming.text, adapter.incoming.reference) }
)

# In the job:
outbound = bot.outbound(reference)   # a Hash; JSON round trips are fine
message_id = outbound.post("Working on it...")
outbound.edit(message_id, answer) if outbound.supports_edit?
```

For Teams, the reference also holds `tenant_id`, `conversation_type` (`"personal"` for 1:1 chats) and `author_platform_id` (the user's Microsoft Entra object id). Use these to decide who the sender is in your app.

## Adding a platform

Any ChatSDK adapter works without changes, for example `chat_sdk-slack` or `chat_sdk-whatsapp`. Add it to the `adapters:` hash and mount its webhook. For a platform that ChatSDK does not support, see [ADAPTERS.md](ADAPTERS.md).

## Known limitations

- ChatSDK Ruby is in beta. This gem pins `~> 1.1`. Its own adapter interface (`Adapters::Base`) keeps that dependency in one place.
- The gem works around three ChatSDK 1.1 problems: the shared-tenant token URL (`Teams.single_tenant!`), request bodies that are not rewindable under Rack 3 (`Bot#webhooks` adds `Rack::RewindableInput::Middleware`), and `on_subscribed_message` firing in threads the bot does not follow.
- History keeps user and assistant text only. Tool calls and tool results are not replayed in later turns.
- Tools that need human approval (`chat.waiting?`) are not supported yet. The bot posts whatever text the model returned.
- Attachments in incoming messages are not sent to the model yet.

## Development

```sh
bin/setup
bundle exec rspec
bundle exec rubocop
```

## License

MIT. See [LICENSE.txt](LICENSE.txt).
