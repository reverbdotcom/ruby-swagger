require 'ruby-swagger/grape/type'

module Swagger::Grape
  class Param
    def initialize(param)
      @param = param
    end

    def to_swagger
      set_attributes do |swagger_param|
        swagger_param['required'] = @param[:required] if @param.key?(:required)
      end
    end

    def to_swagger_without_required
      set_attributes
    end

    def has_type_definition?
      type.casecmp('object').zero?
    end

    def type_definition
      Object.const_get(type).to_s
    end

    def type
      @param[:type].to_s || 'string'
    end

    private

    def set_attributes
      swagger_param = {}
      swagger_param['description'] = @param[:desc]  if @param[:desc].present?
      swagger_param['default'] = @param[:default]   if @param[:default].present?
      yield swagger_param if block_given?
      swagger_param['enum'] = @param[:values] if @param[:values].present?

      swagger_param.merge! Swagger::Grape::Type.new(@param[:type]).to_swagger

      swagger_param
    end
  end
end
