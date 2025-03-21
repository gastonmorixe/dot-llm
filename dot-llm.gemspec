# frozen_string_literal: true

# :main:dot-llm
# This is the primary gem specification file for the "dot-llm" gem.

Gem::Specification.new do |spec|
  spec.name          = "dot-llm"
  spec.version       = "0.2.0"
  spec.authors       = ["Your Name"]
  spec.email         = ["you@example.com"]
  spec.summary       = %q{Serve LLM-friendly Markdown responses in Rails.}
  spec.description   = %q{
    The dot-llm gem adds a new :llm format to Rails controllers, 
    enabling you to serve LLM-friendly Markdown. It automatically 
    extracts key content from your existing HTML responses, or you can 
    override with custom templates to produce a streamlined Markdown 
    response for large language models.
  }
  spec.homepage      = "http://example.com/dot-llm"
  spec.license       = "MIT"

  # The files that will be included in the gem
  spec.files         = Dir["lib/**/*", "README.md", "spec/**/*", "dot-llm.gemspec"]
  spec.require_paths = ["lib"]

  spec.add_dependency "rails", ">= 5.2"
  spec.add_dependency "nokogiri", ">= 1.13.0"
  spec.add_dependency "reverse_markdown", ">= 2.0"

  # Development dependencies
  spec.add_development_dependency "rspec", "~> 3.0"
end