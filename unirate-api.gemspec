# frozen_string_literal: true

lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "unirate/version"

Gem::Specification.new do |spec|
  spec.name          = "unirate-api"
  spec.version       = UniRate::VERSION
  spec.authors       = ["Unirate Team"]
  spec.email         = ["support@unirateapi.com"]

  spec.summary       = "Official Ruby client for the UniRate API."
  spec.description   = "Official Ruby client for the UniRate API — free currency exchange rates, historical data, and VAT rates."
  spec.homepage      = "https://github.com/UniRate-API/unirate-api-ruby"
  spec.license       = "MIT"

  spec.required_ruby_version = ">= 3.0"

  spec.metadata = {
    "homepage_uri"      => spec.homepage,
    "source_code_uri"   => spec.homepage,
    "bug_tracker_uri"   => "#{spec.homepage}/issues",
    "documentation_uri" => "https://unirateapi.com",
    "rubygems_mfa_required" => "true"
  }

  spec.files = Dir[
    "lib/**/*.rb",
    "README.md",
    "LICENSE",
    "unirate-api.gemspec"
  ]
  spec.require_paths = ["lib"]

  # Pure stdlib: no runtime dependencies.

  spec.add_development_dependency "rspec", "~> 3.12"
  spec.add_development_dependency "webmock", "~> 3.19"
end
