# Rails setup

`config/initializers/llm_bot.rb`:

```ruby
require "chat_sdk/teams"
require "chat_sdk/state/redis"

RubyLLM::Messaging.configure do |config|
  config.model = "claude-sonnet-5-5"
  config.instructions = "You are the help desk assistant."
  config.on_error = ->(error, _incoming) { Rails.error.report(error) }
end

LLM_BOT = RubyLLM::Messaging::Bot.new(
  user_name: "helpdesk",
  adapters: { teams: ChatSDK::Teams::Adapter.new },
  state: ChatSDK::State::Redis.new(url: ENV.fetch("REDIS_URL"))
)
```

`config/routes.rb`:

```ruby
mount LLM_BOT.webhooks[:teams], at: "/api/messages"
```
