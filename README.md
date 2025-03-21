# dot-llm

**dot-llm** is a Ruby gem that integrates with Ruby on Rails to deliver responses optimized for large language models (LLMs) by converting HTML into a simplified Markdown format. It registers a new MIME type (`text/llm`) and provides a custom renderer that extracts core content from your HTML—removing extraneous elements like navigation, headers, footers, and more—while converting important HTML elements (for example, bold text) into Markdown.

> [!IMPORTANT]  
> If you see this note it means that this gem is still a WIP and it hasn't been published yet. DO NOT USE IT IN PRODUCTION. 

## Features

- **Custom LLM Response Format:**  
  Registers a new MIME type and renderer for `:llm`, so controllers can respond with LLM-friendly Markdown via `format.llm`.

- **Automatic Content Extraction:**  
  Strips out extraneous HTML elements (e.g. `<nav>`, `<header>`, `<footer>`, `<aside>`, `<script>`, `<style>`) to focus on the core content.

- **HTML to Markdown Conversion:**  
  Uses [ReverseMarkdown](https://github.com/xijo/reverse_markdown) to convert HTML to Markdown—e.g., converting `<b>World</b>` into `**World**`.

- **Custom Template Support:**  
  Supports custom LLM templates (e.g. `.llm.md.erb`), allowing you to override the default behavior if desired.

## Installation

Add the following line to your application's Gemfile:

```ruby
gem 'dot-llm', '~> 0.2.0'
```

Then run:

```bash
bundle install
```

Alternatively, install it directly using:

```bash
gem install dot-llm
```

## Usage

### Basic Controller Integration

In your Rails controller, include `:llm` in your `respond_to` list. For example:

```ruby
class ArticlesController < ApplicationController
  respond_to :html, :json, :llm

  def show
    @article = Article.find(params[:id])
    respond_to do |format|
      format.html  # renders the standard HTML view
      format.json  { render json: @article }
      format.llm   # renders an LLM-optimized Markdown version
    end
  end
end
```

If no custom LLM template exists, **dot-llm** will render your regular HTML view, extract the main content (removing extraneous elements), and convert it to Markdown automatically.

### Using Custom LLM Templates

For complete control over the LLM output, you can create a custom template. For example, place a file at:

```
app/views/articles/show.llm.md.erb
```

With content like:

```erb
# <%= @article.title %>

<%= @article.body %>

---

_Thank you for reading!_
```

Rails will render this template for LLM requests, allowing you to tailor the Markdown output exactly as needed.

### Customizing Content Extraction

The default extraction removes elements matching the selectors: `nav, header, footer, aside, script, style`. You can override this behavior using the helper method:

```ruby
markdown = DotLlm::Railtie.convert_html_to_markdown(your_html_string, ["nav", "header", "footer", "custom-selector"])
```

This flexibility lets you customize which parts of your HTML should be removed before conversion.

## Testing

The gem comes with an extensive RSpec suite that simulates a minimal Rails environment to test responses in HTML, JSON, and the custom LLM format.

### Running the Tests

From the gem’s root directory, run:

```bash
bundle exec rspec
```

The tests verify that:

- **HTML requests** return the full HTML (with extraneous tags intact).
- **JSON requests** return the expected JSON object.
- **LLM requests** return Markdown where extraneous tags have been removed and key HTML (e.g. `<b>World</b>`) is converted to Markdown (`**World**`).

## Contributing

Contributions, bug reports, and pull requests are welcome! Please check out the [GitHub repository](https://github.com/gastonmorixe/dot-llm) for more details. Contributors are expected to adhere to the project's code of conduct.

## License

This gem is available as open source under the terms of the [MIT License](LICENSE).
Author: Gaston Morixe 2025
