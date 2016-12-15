require 'ruby-swagger/data/operation'
require 'ruby-swagger/grape/type'
require 'ruby-swagger/grape/route_settings'

module Swagger::Grape
  class Method
    attr_reader :operation, :types, :scopes

    def initialize(route_name, route)
      @route_settings = Swagger::Grape::RouteSettings.new(route)
      @route_name = route_name
      @route = route
      @types = []
      @scopes = []

      new_operation
      operation_params
      operation_responses
      operation_security

      self
    end

    private

    # generate the base of the operation
    def new_operation
      @operation = Swagger::Data::Operation.new
      @operation.tags = grape_tags
      @operation.operationId = @route_settings.api_name if @route_settings.api_name && !@route_settings.api_name.empty?
      @operation.summary = @route_settings.description
      @operation.description = (@route_settings.detail && !@route_settings.detail.empty?) ? @route_settings.detail : @route_settings.description
      @operation.deprecated = @route_settings.deprecated if @route_settings.deprecated # grape extension

      @operation
    end

    # extract all the parameters from the method definition (in path, url, body)
    def operation_params
      extract_params_and_types

      @params.each do |_param_name, parameter|
        operation.add_parameter(parameter)
      end
    end

    # extract the data about the response of the method
    def operation_responses
      @operation.responses = Swagger::Data::Responses.new

      # Include all the possible errors in the response (store the types, they are documented separately)
      (@route_settings.errors || {}).each do |code, response|
        error_response = { 'description' => response['description'] || response[:description] }

        if (entity = (response[:entity] || response['entity']))
          type = Object.const_get entity.to_s

          error_response['schema'] = {}
          error_response['schema']['$ref'] = "#/definitions/#{type}"

          remember_type(type)
        end

        @operation.responses.add_response(code, Swagger::Data::Response.parse(error_response))
      end

      if @route_settings.response.present? && @route_settings.response[:entity].present?
        rainbow_response = { 'description' => 'Successful result of the operation' }

        type = Swagger::Grape::Type.new(@route_settings.response[:entity].to_s)
        rainbow_response['schema'] = {}
        remember_type(@route_settings.response[:entity])

        # Include any response headers in the documentation of the response
        if @route_settings.response[:headers].present?
          @route_settings.response[:headers].each do |header_key, header_value|
            next unless header_value.present?
            rainbow_response['headers'] ||= {}

            rainbow_response['headers'][header_key] = {
              'description' => header_value['description'] || header_value[:description],
              'type' => header_value['type'] || header_value[:type],
              'format' => header_value['format'] || header_value[:format]
            }
          end
        end
        # rubocop:disable IfInsideElse

        if @route_settings.response[:root].present?
          # A case where the response contains a single key in the response

          if @route_settings.response[:isArray] == true
            # an array that starts from a key named root
            rainbow_response['schema']['type'] = 'object'
            rainbow_response['schema']['properties'] = {
              @route_settings.response[:root] => {
                'type' => 'array',
                'items' => type.to_swagger
              }
            }
          else
            rainbow_response['schema']['type'] = 'object'
            rainbow_response['schema']['properties'] = {
              @route_settings.response[:root] => type.to_swagger
            }
          end

        else

          if @route_settings.response[:isArray] == true
            rainbow_response['schema']['type'] = 'array'
            rainbow_response['schema']['items'] = type.to_swagger
          else
            rainbow_response['schema'] = type.to_swagger
          end

        end
        # rubocop:enable IfInsideElse

        @operation.responses.add_response('200', Swagger::Data::Response.parse(rainbow_response))
      end

      @operation.responses.add_response('default', Swagger::Data::Response.parse({ 'description' => 'Unexpected error' }))
    end

    def operation_security
      if @route_settings.scopes # grape extensions
        security = Swagger::Data::SecurityRequirement.new
        security.add_requirement('oauth2', @route_settings.scopes)
        @operation.security = [security]

        @route_settings.scopes.each do |scope|
          @scopes << scope unless @scopes.include?(scope)
        end
      end
    end

    # extract the tags
    def grape_tags
      (@route_settings.tags && !@route_settings.tags.empty?) ? @route_settings.tags : [@route_name.split('/')[1]]
    end

    def extract_params_and_types
      @params = {}

      header_params
      path_params

      case @route_settings.method.downcase
      when 'get'
        query_params
      when 'delete'
        query_params
      when 'post'
        body_params
      when 'put'
        body_params
      when 'patch'
        body_params
      when 'head'
        raise ArgumentError.new("Don't know how to handle the http verb HEAD for #{@route_name}")
      else
        raise ArgumentError.new("Don't know how to handle the http verb #{@route_settings.method} for #{@route_name}")
      end

      @params
    end

    def header_params
      @params ||= {}

      # include all the parameters that are in the headers
      if @route_settings.headers
        @route_settings.headers.each do |header_key, header_value|
          @params[header_key] = { 'name' => header_key,
                                  'in' => 'header',
                                  'required' => (header_value[:required] == true),
                                  'type' => 'string',
                                  'description' => header_value[:description] }
        end
      end

      @params
    end

    def path_params
      # include all the parameters that are in the path

      @route_name.scan(/\{[a-zA-Z0-9\-\_]+\}/).each do |parameter| # scan all parameters in the url
        param_name = parameter[1..parameter.length - 2]
        @params[param_name] = { 'name' => param_name,
                                'in' => 'path',
                                'required' => true,
                                'type' => 'string' }
      end
    end

    def query_params
      @route_settings.params.each do |parameter|
        next if @params[parameter.first.to_s]

        swag_param = Swagger::Data::Parameter.from_grape(parameter)
        next unless swag_param

        swag_param.in = 'query'

        @params[parameter.first.to_s] = swag_param
      end
    end

    def body_params
      # include all the parameters that are in the content-body
      return unless @route_settings.params && !@route_settings.params.empty?

      body_name = @operation.operationId ? "#{@operation.operationId}_body" : 'body'
      root_param = Swagger::Data::Parameter.parse({ 'name' => body_name,
                                                    'in' => 'body',
                                                    'description' => 'the content of the request',
                                                    'schema' => { 'type' => 'object', 'properties' => {} } })

      # create the params schema
      @route_settings.params.each do |parameter|
        param_name = parameter.first
        param_value = parameter.last
        schema = root_param.schema

        next if @params.keys.include?(param_name)

        if param_name.scan(/[0-9a-zA-Z_]+/).count == 1
          # it's a simple parameter, adding it to the properties of the main object
          converted_param = Swagger::Grape::Param.new(param_value)
          schema.properties[param_name] = converted_param.to_swagger_without_required
          required_parameter(schema, param_name, param_value)
          documented_paramter(schema, param_name, param_value)
          remember_type(converted_param.type_definition) if converted_param.has_type_definition?
        else
          schema_with_subobjects(schema, param_name, parameter.last)
        end
      end

      schema = root_param.schema
      @params['body'] = root_param if !schema.properties.nil? && !schema.properties.keys.empty?
    end

    # Can potentionelly be used for per-param documentation, for now used for example values
    def documented_paramter(schema, target, parameter)
      return if parameter.nil? || parameter[:documentation].nil?
      unless parameter[:documentation][:example].nil?
        schema['example'] ||= {}
        if target.is_a? Array
          nesting = target[0]
          target = target[1]
          schema['example'][nesting] ||= {}
          schema['example'][nesting][target] = parameter[:documentation][:example]
        else
          schema['example'][target] = parameter[:documentation][:example]
        end
      end
    end

    def required_parameter(schema, name, parameter)
      return if parameter.nil? || parameter[:required].nil? || parameter[:required] == false

      schema['required'] = [] unless schema['required'].is_a?(Array)
      schema['required'] << name
    end

    def schema_with_subobjects(schema, param_name, parameter)
      path = param_name.scan(/[0-9a-zA-Z_]+/)
      append_to = find_elem_in_schema(schema, path.dup)
      converted_param = Swagger::Grape::Param.new(parameter)

      append_to['properties'][path.last] = converted_param.to_swagger_without_required

      remember_type(converted_param.type_definition) if converted_param.has_type_definition?
      required_parameter(append_to, path.last, parameter)
      documented_paramter(schema, path, parameter)
    end

    def find_elem_in_schema(root, schema_path)
      return root if schema_path.nil? || schema_path.empty?

      next_elem = schema_path.shift

      return root if root['properties'][next_elem].nil?

      case root['properties'][next_elem]['type']
      when 'array'
        # to descend an array this must be an array of objects
        root['properties'][next_elem]['items']['type'] = 'object'
        root['properties'][next_elem]['items']['properties'] ||= {}

        find_elem_in_schema(root['properties'][next_elem]['items'], schema_path)
      when 'object'
        find_elem_in_schema(root['properties'][next_elem], schema_path)
      else
        raise ArgumentError.new("Don't know how to handle the schema path #{schema_path.join('/')}")
      end
    end

    # Store an object "type" seen on parameters or response types
    def remember_type(type)
      @types ||= []

      return if %w(string integer boolean float array symbol virtus::attribute::boolean rack::multipart::uploadedfile date datetime).include?(type.to_s.downcase)

      type = Object.const_get type.to_s
      return if @types.include?(type.to_s)

      @types << type.to_s
    end
  end
end
