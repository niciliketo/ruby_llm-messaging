# frozen_string_literal: true

require "ruby_llm/messaging"
require "chat_sdk/testing"
require "rack/lint"
require "rack/mock"

Dir[File.join(__dir__, "support/**/*.rb")].each { |file| require file }

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.include ChatSDK::Testing::Helpers
  config.after { RubyLLM::Messaging.reset_configuration! }
end
