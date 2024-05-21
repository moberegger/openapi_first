# frozen_string_literal: true

require 'action_dispatch'

RSpec.describe OpenapiFirst::ResponseParser do
  let(:response_definition) do
    instance_double(OpenapiFirst::Definition::Response,
                    content_type: 'application/json',
                    headers: {})
  end

  subject(:parsed) do
    described_class.new(response_definition).parse(rack_response)
  end

  describe '#body' do
    let(:rack_response) do
      app_response = Rack::Response.new(JSON.dump({ foo: :bar }), 200, { 'Content-Type' => 'application/json' }).to_a
      Rack::Response[*app_response]
    end

    it 'returns the parsed body' do
      expect(parsed.body).to eq('foo' => 'bar')
    end

    context 'without json content-type' do
      let(:rack_response) do
        Rack::Response.new(JSON.dump({ foo: :bar }))
      end

      it 'also parses the body' do
        expect(parsed.body).to eq({ 'foo' => 'bar' })
      end
    end

    context 'with invalid JSON' do
      let(:rack_response) do
        Rack::Response.new('{foobar}', 200, { 'Content-Type' => 'application/json' })
      end

      it 'raises an error' do
        expect do
          parsed.body
        end.to raise_error OpenapiFirst::ResponseInvalidError
      end
    end

    context 'when using Rails' do
      let(:rack_response) do
        app_response = ActionDispatch::Response.create(200, { 'Content-Type' => 'application/json' },
                                                       JSON.dump({ foo: :bar })).to_a
        Rack::Response[*app_response]
      end

      it 'returns the parsed body' do
        expect(parsed.body).to eq('foo' => 'bar')
      end
    end

    context 'when using Rails tests' do
      let(:rack_response) do
        app_response = Rack::Response.new(JSON.dump({ foo: :bar }), 200, { 'Content-Type' => 'application/json' })
        ActionDispatch::TestResponse.from_response(app_response)
      end

      it 'returns the parsed body' do
        expect(parsed.body).to eq('foo' => 'bar')
      end
    end
  end

  describe '#headers' do
    let(:response_definition) do
      instance_double(OpenapiFirst::Definition::Response,
                      content_type: nil,
                      headers: {
                        'OptionalWithoutSchema' => { description: 'optonal' },
                        'Content-Type' => {
                          'required' => true,
                          'schema' => {
                            'type' => 'string',
                            'const' => 'this should be ignored'
                          }
                        },
                        'Location' => {
                          'required' => true,
                          'schema' => {
                            'type' => 'string',
                            format: 'uri-reference'
                          }
                        },
                        'X-Id' => {
                          'schema' => { 'type' => 'integer' }
                        }
                      })
    end

    let(:rack_response) do
      headers = {
        'Content-Type' => 'application/json',
        'Unknown' => 'Cow',
        'X-Id' => '42'
      }
      Rack::Response.new('', 201, headers)
    end

    it 'returns the unpacked headers as defined in the API description' do
      expect(parsed.headers).to eq(
        'Content-Type' => 'application/json',
        'X-Id' => 42
      )
    end

    context 'when response has no headers' do
      let(:rack_response) { Rack::Response.new }

      it 'is empty' do
        expect(parsed.headers).to eq({})
      end
    end

    context 'when no headers are defined' do
      let(:rack_response) do
        Rack::Response.new('{}', 204)
      end

      it 'is empty' do
        expect(parsed.headers).to eq({})
      end
    end

    context 'when response is not defined' do
      let(:rack_response) do
        Rack::Response.new('', 209)
      end

      it 'is empty' do
        expect(parsed.headers).to eq({})
      end
    end
  end
end
