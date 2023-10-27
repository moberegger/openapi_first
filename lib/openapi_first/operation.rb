# frozen_string_literal: true

require 'forwardable'
require 'set'
require_relative 'schema_validation'

module OpenapiFirst
  class Operation # rubocop:disable Metrics/ClassLength
    extend Forwardable
    def_delegators :operation_object,
                   :[],
                   :dig

    WRITE_METHODS = Set.new(%w[post put patch delete]).freeze
    private_constant :WRITE_METHODS

    attr_reader :path, :method, :openapi_version

    def initialize(path, request_method, path_item_object, openapi_version:)
      @path = path
      @method = request_method
      @path_item_object = path_item_object
      @openapi_version = openapi_version
    end

    def operation_id
      operation_object['operationId']
    end

    def read?
      !write?
    end

    def write?
      WRITE_METHODS.include?(method)
    end

    def request_body
      operation_object['requestBody']
    end

    def response_body_schema(status, content_type)
      content = response_for(status)['content']
      return if content.nil? || content.empty?

      raise ResponseInvalid, "Response has no content-type for '#{name}'" unless content_type

      media_type = find_content_for_content_type(content, content_type)

      unless media_type
        message = "Response content type not found '#{content_type}' for '#{name}'"
        raise ResponseContentTypeNotFoundError, message
      end
      schema = media_type['schema']
      return unless schema

      SchemaValidation.new(schema, write: false, openapi_version:)
    end

    def request_body_schema(request_content_type)
      (@request_body_schema ||= {})[request_content_type] ||= begin
        content = operation_object.dig('requestBody', 'content')
        media_type = find_content_for_content_type(content, request_content_type)
        schema = media_type&.fetch('schema', nil)
        SchemaValidation.new(schema, write: write?, openapi_version:) if schema
      end
    end

    def response_for(status)
      response_content = response_by_code(status)
      return response_content if response_content

      message = "Response status code or default not found: #{status} for '#{name}'"
      raise OpenapiFirst::ResponseCodeNotFoundError, message
    end

    def name
      @name ||= "#{method.upcase} #{path} (#{operation_id})"
    end

    def valid_request_content_type?(request_content_type)
      content = operation_object.dig('requestBody', 'content')
      return false unless content

      !!find_content_for_content_type(content, request_content_type)
    end

    def query_parameters
      @query_parameters ||= all_parameters.filter { |p| p['in'] == 'query' }
    end

    def path_parameters
      @path_parameters ||= all_parameters.filter { |p| p['in'] == 'path' }
    end

    IGNORED_HEADERS = Set['Content-Type', 'Accept', 'Authorization'].freeze
    private_constant :IGNORED_HEADERS

    def header_parameters
      @header_parameters ||= all_parameters.filter { |p| p['in'] == 'header' && !IGNORED_HEADERS.include?(p['name']) }
    end

    def cookie_parameters
      @cookie_parameters ||= all_parameters.filter { |p| p['in'] == 'cookie' }
    end

    def all_parameters
      @all_parameters ||= begin
        parameters = @path_item_object['parameters']&.dup || []
        parameters_on_operation = operation_object['parameters']
        parameters.concat(parameters_on_operation) if parameters_on_operation
        parameters
      end
    end

    # Return JSON Schema of for all query parameters
    def query_parameters_schema
      @query_parameters_schema ||= build_json_schema(query_parameters)
    end

    # Return JSON Schema of for all path parameters
    def path_parameters_schema
      @path_parameters_schema ||= build_json_schema(path_parameters)
    end

    def header_parameters_schema
      @header_parameters_schema ||= build_json_schema(header_parameters)
    end

    def cookie_parameters_schema
      @cookie_parameters_schema ||= build_json_schema(cookie_parameters)
    end

    private

    # Build JSON Schema for given parameter definitions
    # @parameter_defs [Array<Hash>] Parameter definitions
    def build_json_schema(parameter_defs)
      init_schema = {
        'type' => 'object',
        'properties' => {},
        'required' => []
      }
      schema = parameter_defs.each_with_object(init_schema) do |parameter_def, result|
        parameter = OpenapiParameters::Parameter.new(parameter_def)
        result['properties'][parameter.name] = parameter.schema if parameter.schema
        result['required'] << parameter.name if parameter.required?
      end
      SchemaValidation.new(schema, openapi_version:)
    end

    def response_by_code(status)
      operation_object.dig('responses', status.to_s) ||
        operation_object.dig('responses', "#{status / 100}XX") ||
        operation_object.dig('responses', "#{status / 100}xx") ||
        operation_object.dig('responses', 'default')
    end

    def operation_object
      @path_item_object[method]
    end

    def find_content_for_content_type(content, request_content_type)
      content.fetch(request_content_type) do |_|
        type = request_content_type.split(';')[0]
        content[type] || content["#{type.split('/')[0]}/*"] || content['*/*']
      end
    end
  end
end
