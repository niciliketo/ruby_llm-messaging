# frozen_string_literal: true

require_relative "lib/ruby_llm/messaging/version"

Gem::Specification.new do |spec|
  spec.name = "ruby_llm-messaging"
  spec.version = RubyLLM::Messaging::VERSION
  spec.authors = ["Nicholas Martin"]
  spec.email = ["niciliketo@gmail.com"]

  spec.summary = "Connect RubyLLM chats to messaging apps such as Microsoft Teams."
  spec.description = "Answers messages in Microsoft Teams and other messaging apps with a RubyLLM chat. " \
                     "Streams replies, keeps conversation history per thread and uses ChatSDK for the platform work."
  spec.homepage = "https://github.com/niciliketo/ruby_llm-messaging"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  # Uncomment the line below to require MFA for gem pushes.
  # This helps protect your gem from supply chain attacks by ensuring
  # no one can publish a new version without multi-factor authentication.
  # See: https://guides.rubygems.org/mfa-requirement-opt-in/
  spec.metadata["rubygems_mfa_required"] = "true"
  spec.metadata["source_code_uri"] = spec.homepage

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ Gemfile .gitignore .rspec spec/ .github/ .rubocop.yml])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "chat_sdk", "~> 1.1"
  spec.add_dependency "ruby_llm", ">= 1.6", "< 3"

  # For more information and examples about making a new gem, check out our
  # guide at: https://guides.rubygems.org/make-your-own-gem/
end
