# frozen_string_literal: true

module OpenapiFirst
  module RequestValidation
    class Validator
      def initialize(operation)
        @operation = operation
      end

      def validate(runtime_request)
        catch(FAIL) do
          validate_defined(runtime_request)
          validate_parameters!(runtime_request)
          validate_request_body!(runtime_request)
          nil
        end
      end

      private

      attr_reader :operation, :raw_path_params

      def validate_defined(request)
        return if request.known?
        return RequestValidation.fail!(:not_found) unless request.known_path?

        RequestValidation.fail!(:method_not_allowed) unless request.known_request_method?
      end

      def validate_parameters!(request)
        validate_query_params!(request)
        validate_path_params!(request)
        validate_cookie_params!(request)
        validate_header_params!(request)
      end

      def validate_path_params!(request)
        parameters = operation.path_parameters
        return unless parameters

        validation = parameters.schema.validate(request.path_params)
        RequestValidation.fail!(:invalid_path, errors: validation.errors) if validation.error?
      end

      def validate_query_params!(request)
        parameters = operation.query_parameters
        return unless parameters

        validation = parameters.schema.validate(request.query)
        RequestValidation.fail!(:invalid_query, errors: validation.errors) if validation.error?
      end

      def validate_cookie_params!(request)
        parameters = operation.cookie_parameters
        return unless parameters

        validation = parameters.schema.validate(request.cookies)
        RequestValidation.fail!(:invalid_cookie, errors: validation.errors) if validation.error?
      end

      def validate_header_params!(request)
        parameters = operation.header_parameters
        return unless parameters

        validation = parameters.schema.validate(request.headers)
        RequestValidation.fail!(:invalid_header, errors: validation.errors) if validation.error?
      end

      def validate_request_body!(request)
        return unless operation.request_body

        RequestBodyValidator.new(operation).validate!(request.body, request.content_type)
      rescue BodyParser::ParsingError => e
        RequestValidation.fail!(:invalid_body, message: e.message)
      end
    end
  end
end
