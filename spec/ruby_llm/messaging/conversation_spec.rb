# frozen_string_literal: true

RSpec.describe RubyLLM::Messaging::Conversation do
  subject(:conversation) { described_class.new(key: "teams:c:t", store: store, config: config) }

  let(:store) { RubyLLM::Messaging::Stores::Memory.new }
  let(:chats) { [] }
  let(:config) do
    RubyLLM::Messaging::Configuration.new.tap do |c|
      c.instructions = "Be brief."
      c.chat_factory = lambda { |_config|
        FakeChat.new.tap { |chat| chats << chat }
      }
    end
  end

  it "streams chunks and returns the full reply" do
    chunks = []

    reply = conversation.ask("Hi") { |chunk| chunks << chunk }

    expect(chunks).to eq(["Hello", " there"])
    expect(reply).to eq("Hello there")
  end

  it "applies the configured instructions and tools" do
    config.tools = [:a_tool]
    conversation.ask("Hi")

    expect(chats.last.instructions).to eq("Be brief.")
    expect(chats.last.tools).to eq([:a_tool])
  end

  it "replays earlier turns into the next chat" do
    conversation.ask("First")
    conversation.ask("Second")

    expect(chats.last.messages).to eq(
      [{ role: :user, content: "First" }, { role: :assistant, content: "Hello there" }]
    )
    expect(chats.last.asked).to eq("Second")
  end

  it "keeps only the most recent messages" do
    config.max_history = 2
    3.times { |i| conversation.ask("Q#{i}") }

    expect(conversation.history).to eq(
      [{ "role" => "user", "content" => "Q2" }, { "role" => "assistant", "content" => "Hello there" }]
    )
  end

  it "does not save the turn when the model fails" do
    config.chat_factory = ->(_config) { FakeChat.new(error: RuntimeError.new("boom")) }

    expect { conversation.ask("Hi") }.to raise_error(RuntimeError, "boom")
    expect(conversation.history).to eq([])
  end
end
