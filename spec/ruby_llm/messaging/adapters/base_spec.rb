# frozen_string_literal: true

RSpec.describe RubyLLM::Messaging::Adapters::Base do
  let(:adapter_class) do
    Class.new(described_class) do
      attr_reader :posts

      def initialize
        super
        @posts = []
      end

      def post(text)
        @posts << text
      end
    end
  end

  it "posts the streamed text once when the platform cannot edit messages" do
    adapter = adapter_class.new

    adapter.stream(placeholder: "Thinking...") do |sink|
      sink << "Hello"
      sink << " there"
    end

    expect(adapter.posts).to eq(["Hello there"])
  end

  it "requires subclasses to describe the incoming message" do
    expect { described_class.new.incoming }.to raise_error(NotImplementedError)
  end
end
