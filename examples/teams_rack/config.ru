# frozen_string_literal: true

# Microsoft Teams bot served by Rack.
#
#   TEAMS_APP_ID=... TEAMS_APP_PASSWORD=... TEAMS_TENANT_ID=... ANTHROPIC_API_KEY=... \
#     bundle exec rackup examples/teams_rack/config.ru -p 3978
#
# Set the Azure Bot messaging endpoint to https://<your-host>/api/messages.

require "ruby_llm/messaging"
require "chat_sdk/teams"

RubyLLM.configure do |config|
  config.anthropic_api_key = ENV.fetch("ANTHROPIC_API_KEY", nil)
end

RubyLLM::Messaging.configure do |config|
  config.model = ENV.fetch("LLM_MODEL", "claude-sonnet-5-5")
  config.instructions = "You are a helpful assistant in Microsoft Teams. Keep answers short."
  config.on_error = ->(error, _incoming) { warn "[ruby_llm-messaging] #{error.class}: #{error.message}" }
end

state =
  if ENV["REDIS_URL"] # needs gem "chat_sdk-state-redis"
    require "chat_sdk/state/redis"
    ChatSDK::State::Redis.new(url: ENV.fetch("REDIS_URL"))
  else
    ChatSDK::State::Memory.new
  end

bot = RubyLLM::Messaging::Bot.new(
  user_name: "assistant",
  adapters: { teams: ChatSDK::Teams::Adapter.new },
  state: state
)

map("/api/messages") { run bot.webhooks[:teams] }
