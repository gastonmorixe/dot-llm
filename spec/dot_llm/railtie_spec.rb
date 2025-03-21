require 'spec_helper'
require 'json'

# Controller using respond_to for three formats.
class FormatsTestController < ActionController::Base
  def index
    respond_to do |format|
      format.html do
        # For HTML, return the full inline HTML (with extraneous tags).
        render inline: '<header>IGNORE</header><main>Hello <b>World</b></main><nav>IGNORE</nav>'
      end
      format.json do
        # For JSON, return a JSON object.
        render json: { message: 'Hello World' }
      end
      format.llm do
        # For LLM, explicitly call our custom renderer.
        render llm: '<header>IGNORE</header><main>Hello <b>World</b></main><nav>IGNORE</nav>'
      end
    end
  end
end

# Controller that directly calls the LLM renderer.
class TestController < ActionController::Base
  def index
    render llm: '<header>IGNORE</header><main>Hello <b>World</b></main><nav>IGNORE</nav>'
  end
end

# Redraw DummyApp routes for our tests.
DummyApp.routes.draw do
  get '/formats' => 'formats_test#index'
  get '/test'    => 'test#index'
end

RSpec.describe 'Response Formats' do
  it 'returns HTML for HTML requests' do
    env = Rack::MockRequest.env_for('/formats', 'HTTP_ACCEPT' => 'text/html')
    status, headers, body = DummyApp.call(env)

    expect(status).to eq(200)
    expect(headers['Content-Type']).to include('text/html')

    content = ''
    body.each { |part| content << part.to_s }

    # HTML should still include the original tags.
    expect(content).to include('<header>IGNORE</header>')
    expect(content).to include('<main>Hello <b>World</b></main>')
    expect(content).to include('<nav>IGNORE</nav>')
  end

  it 'returns JSON for JSON requests' do
    env = Rack::MockRequest.env_for('/formats', 'HTTP_ACCEPT' => 'application/json')
    status, headers, body = DummyApp.call(env)

    expect(status).to eq(200)
    expect(headers['Content-Type']).to include('application/json')

    content = ''
    body.each { |part| content << part.to_s }
    json = JSON.parse(content)

    expect(json['message']).to eq('Hello World')
  end

  it 'returns Markdown for LLM requests via FormatsTestController' do
    env = Rack::MockRequest.env_for('/formats', 'HTTP_ACCEPT' => 'text/llm')
    status, headers, body = DummyApp.call(env)

    expect(status).to eq(200)
    expect(headers['Content-Type']).to include('text/llm')

    content = ''
    body.each { |part| content << part.to_s }

    # Our Railtie should remove extraneous tags and convert <b>World</b> to **World**.
    expect(content).to include('Hello **World**')
    expect(content).not_to include('<header>')
    expect(content).not_to include('<nav>')
  end

  it 'returns Markdown for LLM requests via TestController' do
    env = Rack::MockRequest.env_for('/test', 'HTTP_ACCEPT' => 'text/llm')
    status, headers, body = DummyApp.call(env)

    expect(status).to eq(200)
    expect(headers['Content-Type']).to include('text/llm')

    content = ''
    body.each { |part| content << part.to_s }

    # Again, we expect the conversion to Markdown.
    expect(content).to include('Hello **World**')
    expect(content).not_to include('<header>')
    expect(content).not_to include('<nav>')
  end
end
