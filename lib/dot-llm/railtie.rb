# frozen_string_literal: true

require 'rails'
require 'action_controller'
require 'action_view'
require 'nokogiri'
require 'reverse_markdown'

module DotLlm
  # :main:DotLlm::Railtie
  #
  # = DotLlm::Railtie
  #
  # This Railtie is the heart of the dot-llm gem, hooking into Rails' initialization
  # process, registering the +:llm+ MIME type, adding a +:llm+ renderer, and
  # optionally registering a template handler (for custom .llm.md.erb templates).
  #
  # == Features
  # 1. +:llm+ MIME type registration
  # 2. LLM renderer that extracts main content from rendered HTML, removing extraneous layout
  #    elements (like <header>, <nav>, etc.) and converting to Markdown
  # 3. Optional .md.erb template handler (via ActionView) for direct Markdown + ERB usage
  #
  # == Usage
  # In a Rails controller:
  #
  #     respond_to :html, :llm
  #
  #     def show
  #       @article = Article.find(params[:id])
  #       respond_to do |format|
  #         format.html
  #         format.llm
  #       end
  #     end
  #
  # If you place a custom template, e.g. +show.llm.md.erb+ in +app/views/articles/+,
  # Rails will render that template for +format.llm+. Otherwise, dot-llm will convert
  # the already-rendered HTML into Markdown automatically.
  class Railtie < ::Rails::Railtie
    # The set of CSS selectors we remove by default from the rendered HTML
    # to avoid sending extraneous content (like navigation menus) to the LLM.
    DEFAULT_EXCLUDE_SELECTORS = %w[nav header footer aside script style].freeze

    # Rails initializer that registers the +:llm+ MIME type.
    initializer 'dot_llm.add_mime_type' do
      Mime::Type.register 'text/llm', :llm unless Mime::Type.lookup_by_extension(:llm)
    end

    # Rails initializer that adds the +:llm+ renderer.
    initializer 'dot_llm.add_renderer' do
      # ActionController::Renderers.add :llm do |object, options|
      #   # If a custom template was rendered already, we grab the output
      #   # from response_body. If not, it might be a partial or direct
      #   # data rendering scenario.
      #
      #   rendered_html = controller.response_body.join
      #
      #   # We convert that HTML to Markdown with `extract_main_content`
      #   # which also removes extraneous elements.
      #   markdown = DotLlm::Railtie.convert_html_to_markdown(rendered_html)
      #
      #   # Set the response content_type to :llm
      #   self.content_type ||= Mime[:llm]
      #
      #   # The final output body:
      #   self.response_body = markdown
      # end
      ActionController::Renderers.add :llm do |object, options|
        # Use the object if provided, or fall back to self.response_body
        rendered_html = object || (response_body.is_a?(Array) ? response_body.join : response_body)

        markdown = DotLlm::Railtie.convert_html_to_markdown(rendered_html)

        # Set the Content-Type to :llm if not already set
        self.content_type ||= Mime[:llm]

        # Replace the response body with the markdown output
        self.response_body = markdown
      end
    end

    # Rails initializer that adds a custom template handler for .md.erb,
    # so if you have a file like +index.llm.md.erb+, it can be rendered as
    # normal ERB, then recognized as Markdown. The actual conversion to `.llm`
    # is handled by the +:llm+ renderer.
    initializer 'dot_llm.add_template_handler' do
      # Register a new template handler for .md.erb files
      ActionView::Template.register_template_handler :md_erb, lambda { |template|
        # This code is compiled into a method by ActionView.
        # We simply delegate to ERB, letting it do normal Ruby interpolation,
        # then Rails will produce the final string.
        "ERB.new(#{template.source.inspect}, nil, '-').result(binding)"
      }
    end

    # :call-seq:
    #   convert_html_to_markdown(html, exclude_selectors = DEFAULT_EXCLUDE_SELECTORS) -> String
    #
    # Convert a block of HTML to Markdown, removing extraneous elements first.
    # You can override which elements to remove by passing a list of CSS selectors
    # in +exclude_selectors+. By default, DotLlm removes:
    # <nav>, <header>, <footer>, <aside>, <script>, <style>.
    #
    # Example:
    #   html = "<html><body><nav>Menu</nav><main>Hello World</main></body></html>"
    #   DotLlm::Railtie.convert_html_to_markdown(html)
    #   # => "Hello World"
    #
    # Returns a String in Markdown format.
    def self.convert_html_to_markdown(html, exclude_selectors = DEFAULT_EXCLUDE_SELECTORS)
      # Parse the HTML
      doc = Nokogiri::HTML(html)

      # Remove extraneous elements
      exclude_selectors.each { |sel| doc.css(sel).remove }

      # Attempt to find the main body content
      main_content = doc.at_css('main') || doc.at_css('body') || doc

      # Use inner_html if available to strip out the wrapping tag.
      content_to_convert = main_content.respond_to?(:inner_html) ? main_content.inner_html : main_content.to_s

      # Convert to Markdown using ReverseMarkdown
      ReverseMarkdown.convert(content_to_convert).strip
    rescue StandardError => e
      "[dot-llm error: fallback to text] #{doc.text.strip}"
    end
  end
end
