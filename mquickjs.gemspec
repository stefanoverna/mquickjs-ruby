# frozen_string_literal: true

require_relative "lib/mquickjs/version"

Gem::Specification.new do |spec|
  spec.name          = "mquickjs"
  spec.version       = MQuickJS::VERSION
  spec.authors       = ["Stefano Verna"]
  spec.email         = ["s.verna@datocms.com"]

  spec.summary       = "Secure JavaScript sandbox for Ruby using MicroQuickJS"
  spec.description   = <<~DESC
    MQuickJS provides a secure, memory-safe JavaScript execution environment for Ruby
    applications. Built on MicroQuickJS (a minimal QuickJS engine), it offers strict
    resource limits, sandboxed execution, and comprehensive HTTP security controls.

    Perfect for running untrusted JavaScript code with guaranteed safety - evaluate
    user scripts, process webhooks, execute templates, or build plugin systems without
    compromising your application's security.
  DESC
  spec.homepage      = "https://github.com/stefanoverna/mquickjs-ruby"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 2.7.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["bug_tracker_uri"] = "#{spec.homepage}/issues"
  spec.metadata["documentation_uri"] = "#{spec.homepage}/blob/main/README.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  # Specify which files should be added to the gem when it is released.
  spec.files = Dir.glob([
                          "lib/**/*",
                          "ext/**/*.{c,h,rb}",
                          "README.md",
                          "CHANGELOG.md",
                          "LICENSE",
                          "mquickjs.gemspec"
                        ]).reject { |f| File.directory?(f) }

  spec.require_paths = ["lib"]
  spec.extensions = ["ext/mquickjs/extconf.rb"]
end
