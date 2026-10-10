# frozen_string_literal: true

RSpec.describe RubyLLM::Messaging::Outbound do
  # A fake adapter that, like ChatSDK's Teams adapter, needs a service URL per conversation.
  let(:adapter_class) do
    Class.new(ChatSDK::Testing::FakeAdapter) do
      # ChatSDK keeps capabilities per class, so a subclass declares its own.
      capabilities :edit_messages, :typing_indicator

      attr_reader :service_urls

      def register_service_url(conversation_id, service_url)
        (@service_urls ||= {})[conversation_id] = service_url
      end
    end
  end
  let(:adapter) { adapter_class.new }
  let(:chat) { build_bot(adapters: { test: adapter }) }
  let(:reference) do
    { "platform" => "test", "channel_id" => "C1", "thread_id" => "T1", "service_url" => "https://smba.example/" }
  end

  subject(:outbound) { described_class.new(chat, reference) }

  it "registers the service URL before sending" do
    outbound

    expect(adapter.service_urls).to eq("C1" => "https://smba.example/")
  end

  it "posts and returns the platform message id" do
    id = outbound.post("Hello")

    expect(id).to eq("msg_1")
    expect(adapter.posted_messages.last[:message].text).to eq("Hello")
    expect(adapter.posted_messages.last[:thread_id]).to eq("T1")
  end

  it "edits a message it posted" do
    id = outbound.post("Hel")
    outbound.edit(id, "Hello")

    expect(adapter.edited_messages.last[:message_id]).to eq("msg_1")
    expect(adapter.edited_messages.last[:message].text).to eq("Hello")
  end

  it "reports edit and typing support from the adapter" do
    outbound.start_typing

    expect(outbound.supports_edit?).to be(true)
    expect(adapter.typing_started.size).to eq(1)
  end

  it "works without a service URL for platforms that do not need one" do
    plain = described_class.new(build_bot(adapters: { test: fake_adapter }), platform: :test, channel_id: "C",
                                                                             thread_id: "T")

    expect(plain.post("Hi")).to eq("msg_1")
  end
end
