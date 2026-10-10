# Changelog

## 0.2.1

- Keep ChatSDK's RSpec helpers out of eager loading, so Rails apps boot in production (`config.eager_load = true`).

## 0.2.0

- `Bot.new(handler:)` lets the app handle each message itself, for example by queuing a background job.
- `Incoming#reference` and `Bot#outbound(reference)` send replies to a conversation later, from any process. Teams service URLs are registered automatically.
- `RubyLLM::Messaging::Teams.single_tenant!` makes Single Tenant Azure Bots get tokens from their own tenant.
- `Bot#webhooks` makes request bodies rewindable, so Teams webhooks work under Rack 3 and `Rack::Lint`.
- The gem now loads all of Rack, because ChatSDK uses `Rack::Request` without requiring it.

## 0.1.0

- First release: Microsoft Teams through ChatSDK, streamed replies, per-thread history, hooks.
