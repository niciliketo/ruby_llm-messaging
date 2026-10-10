# frozen_string_literal: true

require "ruby_llm/messaging/teams"

RSpec.describe RubyLLM::Messaging::Teams do
  let(:tenant_id) { "0d461bf6-54a7-45e1-93d2-bf8aa0b37478" }
  let(:adapter) { ChatSDK::Teams::Adapter.new(app_id: "app", app_password: "secret") }
  let(:connection) { instance_double(Faraday::Connection) }

  before { adapter.client.instance_variable_set(:@token_connection, connection) }

  it "sends the token request to the bot's own tenant" do
    described_class.single_tenant!(adapter, tenant_id: tenant_id)
    allow(connection).to receive(:post).and_return(
      instance_double(Faraday::Response, success?: true, body: { "access_token" => "t", "expires_in" => 3600 }.to_json)
    )

    adapter.client.send(:fetch_token)

    expect(connection).to have_received(:post)
      .with("https://login.microsoftonline.com/#{tenant_id}/oauth2/v2.0/token", hash_including(client_id: "app"))
  end

  it "leaves other adapters on the shared tenant" do
    other = ChatSDK::Teams::Adapter.new(app_id: "other", app_password: "secret")
    described_class.single_tenant!(adapter, tenant_id: tenant_id)

    expect(other.client.send(:token_connection)).not_to be_a(described_class::TokenConnection)
  end

  it "rejects a value that is not a tenant id" do
    expect { described_class.single_tenant!(adapter, tenant_id: "botframework.com") }
      .to raise_error(ArgumentError)
  end
end
