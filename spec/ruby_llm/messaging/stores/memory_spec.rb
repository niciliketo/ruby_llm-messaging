# frozen_string_literal: true

RSpec.describe RubyLLM::Messaging::Stores::Memory do
  subject(:store) { described_class.new }

  it "returns an empty history for an unknown key" do
    expect(store.load("teams:c:t")).to eq([])
  end

  it "saves and loads messages per key" do
    store.save("a", [{ "role" => "user", "content" => "hi" }])

    expect(store.load("a")).to eq([{ "role" => "user", "content" => "hi" }])
    expect(store.load("b")).to eq([])
  end

  it "clears a key" do
    store.save("a", [{ "role" => "user", "content" => "hi" }])
    store.clear("a")

    expect(store.load("a")).to eq([])
  end
end
