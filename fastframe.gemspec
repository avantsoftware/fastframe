# frozen_string_literal: true

require_relative "lib/fastframe/version"

Gem::Specification.new do |spec|
  spec.name = "fastframe"
  spec.version = Fastframe::VERSION
  spec.authors = ["Albert Alef"]
  spec.email = ["albertalef@protonmail.com"]

  spec.summary = "Fast and Beautiful Serializer"
  spec.description = "Fast and Beautiful Serializer"
  spec.homepage = "https://github.com/avantsoftware/fastframe"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.6.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = spec.homepage
  spec.metadata["rubygems_mfa_required"] = "true"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir["CHANGELOG.md", "{lib,bin}/**/*", "LICENSE.md", "Rakefile", "README.md"]

  spec.require_paths = ["lib"]

  spec.bindir = "bin"

  # Uncomment to register a new dependency of your gem
  # spec.add_dependency "example-gem", "~> 1.0"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
