# frozen_string_literal: true

RSpec.describe RubyLLM::Messaging::Adapters::ChatSDK do
  subject(:adapter) { described_class.new(thread, message) }

  let(:chat) { build_bot(adapters: { test: fake_adapter }) }
  let(:thread) { ChatSDK::Thread.new(id: "T1", channel_id: "C1", adapter: fake_adapter, chat: chat) }
  let(:message) { build_message(text: text, user_id: "U9", user_name: "Ada") }
  let(:text) { "hello" }

  describe "#incoming" do
    it "describes the message without ChatSDK types" do
      expect(adapter.incoming).to have_attributes(
        text: "hello", author_id: "U9", author_name: "Ada", platform: :test,
        conversation_key: "test:C1:T1", raw: message
      )
    end

    context "with a Teams mention" do
      let(:text) { "<at>Help Bot</at> what is our refund policy?" }

      it "removes the mention markup" do
        expect(adapter.incoming.text).to eq("what is our refund policy?")
      end
    end

    context "with a Slack mention" do
      let(:text) { "<@U0BOT> summarise   this" }

      it "removes the mention markup and extra spaces" do
        expect(adapter.incoming.text).to eq("summarise this")
      end
    end
  end

  it "posts to the thread" do
    adapter.post("Hi")

    expect(fake_adapter.posted_messages.last[:message].text).to eq("Hi")
  end

  it "starts typing when the platform supports it" do
    adapter.start_typing

    expect(fake_adapter.typing_started.size).to eq(1)
  end

  describe "#reference" do
    it "identifies the conversation" do
      expect(adapter.reference).to eq(platform: :test, channel_id: "C1", thread_id: "T1")
      expect(adapter.incoming.reference).to eq(adapter.reference)
    end

    context "with a Teams activity" do
      let(:message) do
        ChatSDK::Message.new(
          id: "1", text: "hi", thread_id: "T1", channel_id: "C1", platform: :teams,
          author: ChatSDK::Author.new(id: "29:x", name: "Ada", platform: :teams),
          raw: {
            "serviceUrl" => "https://smba.trafficmanager.net/emea/",
            "conversation" => { "id" => "a:1", "tenantId" => "tenant-1", "conversationType" => "personal" },
            "from" => { "id" => "29:x", "aadObjectId" => "oid-1" }
          }
        )
      end

      it "adds the service URL, tenant, conversation type and author object id" do
        expect(adapter.reference).to include(
          service_url: "https://smba.trafficmanager.net/emea/", tenant_id: "tenant-1",
          conversation_type: "personal", author_platform_id: "oid-1"
        )
      end
    end
  end
end
