# frozen_string_literal: true

require "ruby_llm"
require "chat_sdk"

# ChatSDK's RSpec helpers (ChatSDK::Testing) reference RSpec, so eager loading them fails outside a test run.
# Rails eager loads every Zeitwerk loader in production (Zeitwerk::Loader.eager_load_all), so keep them out.
# They still load on demand, e.g. require "chat_sdk/testing" in a spec helper.
ChatSDK.loader.dirs.each do |root|
  ChatSDK.loader.do_not_eager_load(File.join(root, "chat_sdk", "testing"), File.join(root, "chat_sdk", "testing.rb"))
end

require_relative "messaging/version"
require_relative "messaging/configuration"
require_relative "messaging/incoming"
require_relative "messaging/stores/memory"
require_relative "messaging/stores/chat_sdk_state"
require_relative "messaging/adapters/base"
require_relative "messaging/adapters/chat_sdk"
require_relative "messaging/conversation"
require_relative "messaging/responder"
require_relative "messaging/outbound"
require_relative "messaging/bot"

module RubyLLM
  # Connects RubyLLM chats to messaging apps such as Microsoft Teams.
  #
  #   RubyLLM::Messaging.configure do |config|
  #     config.model = "claude-sonnet-5-5"
  #     config.instructions = "You are the help desk assistant."
  #   end
  #
  #   bot = RubyLLM::Messaging::Bot.new(
  #     user_name: "helpdesk",
  #     adapters: { teams: ChatSDK::Teams::Adapter.new }
  #   )
  #   map("/webhooks/teams") { run bot.webhooks[:teams] }
  module Messaging
    class Error < StandardError; end

    class << self
      def configuration
        @configuration ||= Configuration.new
      end

      def configure
        yield configuration
      end

      def reset_configuration!
        @configuration = Configuration.new
      end
    end
  end
end
