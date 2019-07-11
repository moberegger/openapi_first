# frozen_string_literal: true

require 'benchmark/ips'
require 'rack'
ENV['RACK_ENV'] = 'production'

configs = Dir['./apps/*.ru']

Benchmark.ips do |x|
  examples = [
    [Rack::MockRequest.env_for('/hello'), 200],
    [Rack::MockRequest.env_for('/unknown'), 404],
    [Rack::MockRequest.env_for('/hello', method: 'POST'), 201],
    [Rack::MockRequest.env_for('/hello/1'), 200],
    [Rack::MockRequest.env_for('/hello/123'), 200],
    [Rack::MockRequest.env_for('/hello?filter[id]=1,2'), 200]
  ]

  configs.each do |config|
    app = Rack::Builder.parse_file(config).first
    x.report(config) do
      examples.each do |example|
        env, expected_status = example
        response = app.call(env)
        raise unless response[0] == expected_status
      end
    end
  end

  x.compare!
end
