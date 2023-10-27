# frozen_string_literal: true

module OpenapiFirst
  # This is the base class for error responses
  class ErrorResponse
    ## @param status [Integer] The intended HTTP status code.
    ## @param title [String] A descriptive title for the error.
    ## @param location [Symbol] The location of the error (:body, :query, :header, :cookie, :path).
    ## @param validation_result [ValidationResult]
    def initialize(status:, location:, title:, validation_result:)
      @status = status
      @title = title
      @location = location
      @validation_output = validation_result&.output
      @schema = validation_result&.schema
      @data = validation_result&.data
    end

    attr_reader :status, :location, :title, :schema, :data, :validation_output

    def render
      Rack::Response.new(body, status, Rack::CONTENT_TYPE => content_type).finish
    end

    def content_type = 'application/json'

    def body
      raise NotImplementedError
    end
  end
end
