# frozen_string_literal: true

RSpec.describe RubyLLM::Messaging::Responder do
  subject(:responder) { described_class.new(config: config, store: store) }

  let(:store) { RubyLLM::Messaging::Stores::Memory.new }
  let(:fake_chat) { FakeChat.new }
  let(:config) do
    RubyLLM::Messaging::Configuration.new.tap { |c| c.chat_factory = ->(_config) { fake_chat } }
  end
  let(:incoming) do
    RubyLLM::Messaging::Incoming.new(text: "Hi", author_id: "U1", author_name: "Ada",
                                     platform: :test, conversation_key: "test:C:T", raw: nil)
  end
  let(:adapter) do
    instance_double(RubyLLM::Messaging::Adapters::Base, incoming: incoming, post: nil, start_typing: nil)
  end
  let(:streamed) { +"" }

  before do
    allow(adapter).to receive(:stream) { |**_kwargs, &block| block.call(streamed) }
  end

  it "streams the reply through the adapter" do
    expect(responder.call(adapter)).to eq("Hello there")
    expect(streamed).to eq("Hello there")
    expect(adapter).to have_received(:stream).with(placeholder: "Thinking...")
  end

  it "lets before_ask replace the prompt" do
    config.before_ask = ->(message) { "[#{message.author_name}] #{message.text}" }
    responder.call(adapter)

    expect(fake_chat.asked).to eq("[Ada] Hi")
  end

  it "skips the reply when before_ask returns false" do
    config.before_ask = ->(_message) { false }

    expect(responder.call(adapter)).to be_nil
    expect(adapter).not_to have_received(:stream)
  end

  it "calls after_reply with the reply and message" do
    replies = []
    config.after_reply = ->(reply, message) { replies << [reply, message.author_id] }
    responder.call(adapter)

    expect(replies).to eq([["Hello there", "U1"]])
  end

  it "keeps going when the typing indicator fails" do
    allow(adapter).to receive(:start_typing).and_raise(StandardError, "no typing")

    expect(responder.call(adapter)).to eq("Hello there")
  end

  context "when the model fails" do
    let(:fake_chat) { FakeChat.new(error: RuntimeError.new("rate limited")) }

    it "posts the error message and reports the error" do
      errors = []
      config.on_error = ->(error, message) { errors << [error.message, message.text] }

      expect(responder.call(adapter)).to be_nil
      expect(adapter).to have_received(:post).with(config.error_message)
      expect(errors).to eq([["rate limited", "Hi"]])
    end

    it "re-raises when no error handler is set" do
      expect { responder.call(adapter) }.to raise_error(RuntimeError, "rate limited")
      expect(adapter).to have_received(:post).with(config.error_message)
    end
  end
end
