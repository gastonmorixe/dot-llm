require 'bundler/setup'
# Load only the minimal parts of Rails we need.
require 'action_controller/railtie'
require 'rack/mock'
require 'dot-llm'

ActionController::Renderers.add :llm do |object, options|
  # Use the object if provided, or fall back to self.response_body
  rendered_html = object || (response_body.is_a?(Array) ? response_body.join : response_body)

  markdown = DotLlm::Railtie.convert_html_to_markdown(rendered_html)

  # Set the Content-Type to :llm if not already set
  self.content_type ||= Mime[:llm]

  # Replace the response body with the markdown output
  self.response_body = markdown
end

# Define a minimal Rails application for testing.
class DummyApp < Rails::Application
  # Set a dummy root directory.
  config.root = File.expand_path('../dummy', __dir__)
  config.secret_key_base = 'secret'
  config.eager_load = false
  config.consider_all_requests_local = true
  config.active_support.to_time_preserves_timezone = :zone

  config.hosts.clear

  # Disable assets if available.
  config.assets.enabled = false if config.respond_to?(:assets)

  # Unfreeze configuration arrays that might be frozen.
  if config.paths.respond_to?(:paths)
    config.paths.paths.each do |key, path_array|
      # Duplicate the array if it's frozen.
      config.paths.paths[key] = path_array.dup if path_array.frozen?
    end
  end

  # Define a simple route mapping to a dummy controller.
  routes.draw do
    get '/test' => 'test#index'
  end
end

Rails.logger = Logger.new($stdout)
Rails.logger.level = Logger::WARN

DummyApp.initialize!

RSpec.configure do |config|
  config.order = :random
  config.mock_with :rspec
end
