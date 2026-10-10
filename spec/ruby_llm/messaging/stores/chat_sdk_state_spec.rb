# frozen_string_literal: true

RSpec.describe RubyLLM::Messaging::Stores::ChatSDKState do
  subject(:store) { described_class.new(state) }

  let(:state) { ChatSDK::State::Memory.new }
  let(:messages) { [{ "role" => "user", "content" => "hi" }, { "role" => "assistant", "content" => "hello" }] }

  it "round-trips messages through the ChatSDK state as JSON" do
    store.save("teams:c:t", messages)

    expect(store.load("teams:c:t")).to eq(messages)
    expect(state.get("ruby_llm-messaging:history:teams:c:t")).to be_a(String)
  end

  it "returns an empty history for an unknown key" do
    expect(store.load("missing")).to eq([])
  end

  it "clears a key" do
    store.save("k", messages)
    store.clear("k")

    expect(store.load("k")).to eq([])
  end
end
