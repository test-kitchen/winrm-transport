# coding: utf-8
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "winrm/transport/version"
require "English"

Gem::Specification.new do |spec|
  spec.name          = "winrm-transport"
  spec.version       = WinRM::Transport::VERSION
  spec.authors       = ["Fletcher Nichol"]
  spec.email         = ["fnichol@nichol.ca"]

  spec.summary       = "TODO: Write a short summary, because Rubygems requires one."

  spec.description   = spec.summary
  spec.homepage      = "https://github.com/test-kitchen/winrm-transport"
  spec.license       = "Apache 2.0"

  spec.files         = `git ls-files -z`.split("\x0").
    reject { |f| f.match(%r{^(test|spec|features)/}) }

  spec.bindir        = "exe"
  spec.executables   = []
  spec.require_paths = ["lib"]

  spec.required_ruby_version = ">= 1.9.1"

  spec.add_dependency "winrm",    "~> 1.3"
  spec.add_dependency "rubyzip",  ">= 1.1.7", "~> 1.1"

  spec.add_development_dependency "pry"
  spec.add_development_dependency "bundler", "~> 1.9"
  spec.add_development_dependency "rake", "~> 10.0"

  spec.add_development_dependency "fakefs",     "~> 0.4"
  spec.add_development_dependency "minitest"
  spec.add_development_dependency "mocha",      "~> 1.1"

  spec.add_development_dependency "countloc",   "~> 0.4"
  spec.add_development_dependency "maruku",     "~> 0.6"
  spec.add_development_dependency "simplecov",  "~> 0.7"
  spec.add_development_dependency "yard",       "~> 0.8"

  # style and complexity libraries are tightly version pinned as newer releases
  # may introduce new and undesireable style choices which would be immediately
  # enforced in CI
  spec.add_development_dependency "finstyle",  "1.4.0"
  spec.add_development_dependency "cane",      "2.6.2"
end
