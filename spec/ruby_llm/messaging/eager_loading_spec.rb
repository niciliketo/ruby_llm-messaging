# frozen_string_literal: true

require "open3"
require "rbconfig"

RSpec.describe "Eager loading" do
  # Runs in a separate process without RSpec, like a Rails app booting in production.
  it "eager loads every Zeitwerk loader without RSpec" do
    script = 'require "ruby_llm/messaging"; require "ruby_llm/messaging/teams"; ' \
             "Zeitwerk::Loader.eager_load_all; print :ok"
    output, status = Open3.capture2e(RbConfig.ruby, "-I", File.expand_path("../../../lib", __dir__), "-e", script)

    expect(status).to be_success, output
    expect(output).to end_with("ok")
  end
end
