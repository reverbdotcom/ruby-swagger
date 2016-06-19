require 'active_support/concern'
require 'ruby-swagger/grape/route_settings'

module Grape
  module DSL
    module InsideRoute
      def api_present(*args)
        args_list = args || []
        options = {}

        route_settings = Swagger::Grape::RouteSettings.new(route)

        # Initialize the options hash - either by assigning to the current options for the method or with a new one
        if args_list.count == 2

          if args_list.last.is_a?(Hash)
            options = args_list.last
          else
            raise ArgumentError.new "The expected second argument for api_present is a Hash, but I got a #{args_list.last.class}"
          end

        elsif args_list.count == 1

          # Initialize the option list
          args_list << options

        elsif args_list.count > 2 || args_list.count == 0
          raise ArgumentError.new "Invalid number of arguments - got #{args_list.count}. expected 1 or 2 parameters"
        end

        # Setting the grape :with
        if route_settings.response.present? && route_settings.response[:entity].present? && !options[:with].present? && route_settings.response[:entity].is_a?(Class)
          options[:with] = route_settings.response[:entity]
        end

        # Setting the grape :root
        if route_settings.response.present? && route_settings.response[:root].present? && !options[:root].present? && route_settings.response[:root].is_a?(String)
          options[:root] = route_settings.response[:root]
        end

        # Setting the :current_user extension
        options[:current_user] = current_user if defined?(current_user)

        present(*args_list)
      end
    end
  end
end
