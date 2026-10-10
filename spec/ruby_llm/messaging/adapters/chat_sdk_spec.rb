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
end
