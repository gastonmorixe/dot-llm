# frozen_string_literal: true

require 'rails'
require 'action_controller'
require 'action_view'
require 'nokogiri'
require 'reverse_markdown'
require 'ostruct'

# = DotLlm
#
# DotLlm is a lightweight Rails gem designed to transform HTML views into streamlined,
# LLM-friendly Markdown responses. It integrates with Rails by registering a custom MIME type
# (mapped to :llm), adding a renderer that converts rendered HTML into Markdown, and optionally
# supporting custom template handlers for LLM-specific views.
#
# == Features
#
# - Registers the MIME type :llm (mapped to "text/markdown").
# - Provides a custom renderer that extracts core content from HTML—removing extraneous elements
#   like <header>, <nav>, <footer>, and others—and converts it to Markdown using ReverseMarkdown.
# - Overrides the default rendering behavior for LLM requests: if a custom LLM template (e.g.
#   "show.llm.md.erb") exists, it is used; otherwise, the standard HTML view is converted to Markdown.
# - Supports custom template handlers, allowing full control over the Markdown output.
#
# == Usage
#
# In your Rails controller, include :llm in your respond_to block:
#
#   class ArticlesController < ApplicationController
#     def show
#       @article = Article.find(params[:id])
#       respond_to do |format|
#         format.html  # renders the standard HTML view
#         format.json  { render json: @article }
#         format.llm   # renders an LLM-optimized Markdown version
#       end
#     end
#   end
#
# If a custom template is present (e.g. app/views/articles/show.llm.md.erb), it will be used;
# otherwise, DotLlm automatically converts the rendered HTML view to Markdown.
#
# == Configuration
#
# You can customize the content extraction process by extending or overriding the default exclusion
# selectors (e.g. removing additional navigation elements) via configuration.
#
# == License
#
# DotLlm is released under the terms of the MIT License.
module DotLlm
  class << self
    attr_accessor :configuration
  end

  # This module should define methods that help a controller decide how to
  # respond to an LLM request.
  module Responder
    extend ActiveSupport::Concern
    def respond_to_llm
      if lookup_context.template_exists?(action_name, lookup_context.prefixes, false, formats: %i[llm md])
        # Let Rails render the custom LLM template
        render
      else
        # Fallback: render the HTML view and convert it.
        html = render_to_string(action_name, formats: [:html])
        render llm: html
      end
    end
  end

  # A simple template handler that processes Markdown templates.
  module TemplateHandlers
    class Markdown
      def self.call(template)
        # For simplicity, we delegate to ERB so that the template is processed
        # and then returned as a raw string.
        "ERB.new(#{template.source.inspect}, nil, '-').result(binding)"
      end
    end
  end

  # Optional: Middleware that intercepts LLM responses.
  class Middleware
    def initialize(app)
      @app = app
    end

    def call(env)
      status, headers, response = @app.call(env)
      # We can add logic here to modify the response if necessary.
      [status, headers, response]
    end
  end

  class Configuration
    attr_accessor :exclude_selectors

    def initialize
      @exclude_selectors = %w[nav header footer aside script style]
    end
  end

  class << self
    # Returns or sets the configuration for dot-llm.
    attr_accessor :configuration
  end

  # Set default configuration if none exists.
  self.configuration ||= Configuration.new

  class Railtie < ::Rails::Railtie
    # Register the :llm MIME type as text/markdown.
    initializer 'dot_llm.mime_types' do
      Mime::Type.register 'text/markdown', :llm unless Mime::Type.lookup_by_extension(:llm)
    end

    # Include our responder module into all controllers.
    initializer 'dot_llm.action_controller' do
      ActiveSupport.on_load(:action_controller) do
        include DotLlm::Responder
      end
    end

    # Register a template handler for .md (or .llm.md) templates.
    initializer 'dot_llm.template_handler' do
      ActiveSupport.on_load(:action_view) do
        ActionView::Template.register_template_handler :md, DotLlm::TemplateHandlers::Markdown
      end
    end

    # Add our custom :llm renderer.
    initializer 'dot_llm.add_renderer' do
      ActionController::Renderers.add :llm do |object, _options|
        rendered_html = object || (response_body.respond_to?(:join) ? response_body.join : response_body)
        markdown = DotLlm::Railtie.convert_html_to_markdown(rendered_html)
        self.content_type ||= Mime[:llm]
        self.response_body = markdown
      end
    end

    # Override default rendering for LLM format.
    initializer 'dot_llm.override_default_render' do
      ActiveSupport.on_load(:action_controller) do
        class ActionController::Base
          alias old_default_render default_render

          def default_render(*args)
            if request.format.symbol == :llm
              # Instead of always falling back, use our responder which
              # will check for a custom template.
              respond_to_llm
            else
              old_default_render(*args)
            end
          end
        end
      end
    end

    # Optionally add middleware to intercept LLM requests.
    initializer 'dot_llm.middleware' do |app|
      app.middleware.use DotLlm::Middleware
    end

    # Convert HTML to Markdown by removing extraneous elements.
    #
    # @param html [String] The HTML to convert.
    # @param exclude_selectors [Array<String>] The CSS selectors to remove (default: nav, header, footer, aside, script, style).
    # @return [String] The resulting Markdown.
    def self.convert_html_to_markdown(html, exclude_selectors = DotLlm.configuration.exclude_selectors)
      doc = Nokogiri::HTML(html)
      # Remove HTML comments.
      doc.xpath('//comment()').remove

      # Remove extraneous elements based on selectors.
      exclude_selectors.each { |sel| doc.css(sel).remove }

      main_content = doc.at_css('main') || doc.at_css('body') || doc
      content_to_convert = main_content.respond_to?(:inner_html) ? main_content.inner_html : main_content.to_s

      ReverseMarkdown.convert(content_to_convert).strip
    rescue StandardError
      "[dot-llm error: fallback to text] #{doc.text.strip}"
    end
  end
end
