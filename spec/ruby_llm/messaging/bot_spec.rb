# frozen_string_literal: true

RSpec.describe RubyLLM::Messaging::Bot do
  subject(:bot) do
    described_class.new(user_name: "helper", adapters: { test: fake_adapter }, state: state,
                        config: config, streaming_update_interval: 0)
  end

  let(:state) { ChatSDK::State::Memory.new }
  let(:chats) { [] }
  let(:config) do
    RubyLLM::Messaging::Configuration.new.tap do |c|
      c.chat_factory = ->(_config) { FakeChat.new.tap { |chat| chats << chat } }
    end
  end

  def deliver(event_class, text, id:)
    message = ChatSDK::Message.new(
      id: id, text: text, thread_id: "T1", channel_id: "C1", platform: :test,
      author: ChatSDK::Author.new(id: "U1", name: "Ada", platform: :test)
    )
    event = event_class.new(message: message, thread_id: "T1", channel_id: "C1",
                            platform: :test, adapter_name: :test)
    bot.chat_sdk.dispatch(event, adapter_name: :test)
  end

  it "replies to a mention by streaming into a placeholder" do
    deliver(ChatSDK::Events::Mention, "<at>helper</at> Hi", id: "m1")

    expect(fake_adapter.posted_messages.map { |call| call[:message].text }).to eq(["Thinking..."])
    expect(fake_adapter.edited_messages.last[:message].text).to eq("Hello there")
    expect(chats.last.asked).to eq("Hi")
  end

  it "follows the thread after a mention and keeps the history" do
    deliver(ChatSDK::Events::Mention, "First", id: "m1")
    deliver(ChatSDK::Events::SubscribedMessage, "Second", id: "m2")

    expect(chats.size).to eq(2)
    expect(chats.last.messages.map { |message| message[:content] }).to eq(["First", "Hello there"])
  end

  it "ignores messages in threads it does not follow" do
    deliver(ChatSDK::Events::SubscribedMessage, "Chatter", id: "m1")

    expect(chats).to be_empty
    expect(fake_adapter.posted_messages).to be_empty
  end

  it "replies to direct messages" do
    deliver(ChatSDK::Events::DirectMessage, "Hello bot", id: "m1")

    expect(chats.last.asked).to eq("Hello bot")
  end

  it "stores history in the ChatSDK state by default" do
    deliver(ChatSDK::Events::Mention, "Hi", id: "m1")

    expect(bot.store).to be_a(RubyLLM::Messaging::Stores::ChatSDKState)
    expect(bot.store.load("test:C1:T1").size).to eq(2)
  end

  describe "with a custom handler" do
    subject(:bot) do
      described_class.new(user_name: "helper", adapters: { test: fake_adapter }, config: config,
                          handler: ->(adapter) { handled << adapter.incoming })
    end

    let(:handled) { [] }

    it "passes each message to the handler instead of the responder" do
      deliver(ChatSDK::Events::DirectMessage, "Hello bot", id: "m1")

      expect(handled.map(&:text)).to eq(["Hello bot"])
      expect(chats).to be_empty
    end
  end

  describe "#outbound" do
    it "sends to a conversation from its reference" do
      deliver(ChatSDK::Events::DirectMessage, "Hi", id: "m1")
      fake_adapter.reset!

      bot.outbound(platform: :test, channel_id: "C1", thread_id: "T1").post("Later")

      expect(fake_adapter.posted_messages.last[:message].text).to eq("Later")
    end
  end

  describe "#webhooks" do
    # Reads the body twice, as ChatSDK's adapters do.
    let(:adapter_class) do
      Class.new(ChatSDK::Testing::FakeAdapter) do
        attr_reader :bodies

        def parse_events(rack_request)
          (@bodies ||= []) << rack_request.body.read
          rack_request.body.rewind
          @bodies << rack_request.body.read
          []
        end
      end
    end
    let(:adapter) { adapter_class.new }
    let(:bot) { described_class.new(user_name: "helper", adapters: { test: adapter }, config: config) }

    it "makes the request body rewindable under Rack::Lint" do
      app = Rack::Lint.new(bot.webhooks[:test])
      response = Rack::MockRequest.new(app).post("/", input: "{}", "CONTENT_TYPE" => "application/json")

      expect(response.status).to eq(200)
      expect(adapter.bodies).to eq(["{}", "{}"])
    end

    it "returns the same endpoint each time" do
      expect(bot.webhooks[:test]).to be(bot.webhooks[:test])
    end
  end
end
