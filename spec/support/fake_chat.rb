# frozen_string_literal: true

# Stands in for RubyLLM::Chat so specs never call a real model.
class FakeChat
  Reply = Struct.new(:content)
  Chunk = Struct.new(:content)

  attr_reader :instructions, :tools, :messages, :asked

  def initialize(chunks: ["Hello", " there"], error: nil)
    @chunks = chunks
    @error = error
    @messages = []
    @tools = []
  end

  def with_instructions(instructions)
    @instructions = instructions
    self
  end

  def with_tools(*tools)
    @tools = tools
    self
  end

  def add_message(role:, content:)
    @messages << { role: role, content: content }
  end

  def ask(text)
    @asked = text
    raise @error if @error

    @chunks.each { |chunk| yield Chunk.new(chunk) if block_given? }
    Reply.new(@chunks.join)
  end
end
