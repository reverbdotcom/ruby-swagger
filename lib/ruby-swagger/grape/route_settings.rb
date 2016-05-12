module Swagger::Grape
  class RouteSettings
    attr_reader :settings, :options

    def initialize(route)
      @options = route.options || {}
      @settings = route.settings || {}
    end

    def method
      @options.fetch(:method, nil)
    end

    def description
      _description.fetch(:description, nil)
    end

    def prefix
      _description.fetch(:prefix, nil)
    end

    def hidden
      @options.fetch(:hidden, false)
    end

    def deprecated
      _description.fetch(:deprecated, nil)
    end

    def tags
      _description.fetch(:tags, nil) || []
    end

    def api_name
      _description.fetch(:api_name, nil)
    end

    def detail
      _description.fetch(:detail, nil)
    end

    def response
      _description.fetch(:response, nil)
    end

    def errors
      _description.fetch(:errors, nil) || {}
    end

    def params
      _description.fetch(:params, nil) || {}
    end

    def headers
      _description.fetch(:headers, nil) || {}
    end

    def scopes
      _description.fetch(:scopes, nil) || []
    end

    def inspect
      methods = self.class.instance_methods(false) - [:inspect]
      vars = methods.map { |v| "#{v}='#{try(v)}'" }.join(', ')
      "<#{self.class}: #{vars}>"
    end

    private

    def _description
      @settings.try(:[], :description) || {}
    end
  end
end
