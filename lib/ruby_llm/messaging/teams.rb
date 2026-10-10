# frozen_string_literal: true

require "delegate"
require "chat_sdk/teams"

module RubyLLM
  module Messaging
    # Microsoft Teams helpers. Require "ruby_llm/messaging/teams" to use them.
    module Teams
      class << self
        # Makes a ChatSDK Teams adapter request its Bot Framework token from the bot's
        # own Microsoft Entra tenant. Single-tenant Azure Bots need this: ChatSDK 1.1
        # always uses the shared "botframework.com" tenant, so their replies fail.
        #
        #   adapter = ChatSDK::Teams::Adapter.new
        #   RubyLLM::Messaging::Teams.single_tenant!(adapter, tenant_id: ENV["TEAMS_TENANT_ID"])
        #
        # @return the adapter
        def single_tenant!(adapter, tenant_id:)
          raise ArgumentError, "tenant_id must be a Microsoft Entra tenant id" unless tenant_id.to_s.match?(TENANT_ID)

          client = adapter.client
          client.instance_variable_set(:@ruby_llm_messaging_token_url, token_url(tenant_id))
          client.singleton_class.prepend(TenantTokenClient)
          adapter
        end

        def token_url(tenant_id)
          "https://login.microsoftonline.com/#{tenant_id}/oauth2/v2.0/token"
        end
      end

      TENANT_ID = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i

      # Prepended to one BotFrameworkClient instance by Teams.single_tenant!.
      module TenantTokenClient
        private

        def token_connection
          TokenConnection.new(super, @ruby_llm_messaging_token_url)
        end
      end

      # Sends the token request to the tenant's endpoint instead of the shared one.
      class TokenConnection < SimpleDelegator
        def initialize(connection, token_url)
          super(connection)
          @token_url = token_url
        end

        def post(url = nil, ...)
          url = @token_url if url == ::ChatSDK::Teams::BotFrameworkClient::TOKEN_URL
          __getobj__.post(url, ...)
        end
      end
    end
  end
end
