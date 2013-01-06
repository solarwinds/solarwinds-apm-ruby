# Copyright (c) 2012 by Tracelytics, Inc.
# All rights reserved.

module Oboe
  module Inst
    module Rails3ActionController
      def process(*args)

        Oboe::API.trace('rails', {}) do
          super
        end
      end

      def process_action(*args)
        report_kvs = {
          'HTTP-Host'   => @_request.headers['HTTP_HOST'],
          :URL          => @_request.headers['REQUEST_URI'],
          :Method       => @_request.headers['REQUEST_METHOD'],
          :Controller   => self.class.name,
          :Action       => self.action_name,
        }
        super

        report_kvs[:Status] = @_response.status
        Oboe::API.log('rails', 'info', report_kvs)
      
      rescue Exception => exception
        report_kvs[:Status] = 500
        Oboe::API.log('rails', 'info', report_kvs)
        raise
      end

      def render(*args)
        Oboe::API.trace('render', {}) do
          super
        end
      end
    end
  end
end

if defined?(ActionController::Base)
  if ::Rails::VERSION::MAJOR == 3
    Oboe::API.report_init('rails')

    class ActionController::Base
      include Oboe::Inst::Rails3ActionController
    end
  elsif ::Rails::VERSION::MAJOR == 2
    Oboe::API.report_init('rails')

    ActionController::Base.class_eval do
      alias :perform_action_without_oboe :perform_action
      alias :rescue_action_without_oboe :rescue_action
      alias :process_without_oboe :process
      alias :render_without_oboe :render

      def process(*args)
        Oboe::API.trace('rails', {}) do
          process_without_oboe(*args)
        end
      end

      def perform_action(*arguments)
        report_kvs = {
            'HTTP-Host'   => @_request.headers['HTTP_HOST'],
            :URL          => @_request.headers['REQUEST_URI'],
            :Method       => @_request.headers['REQUEST_METHOD'],
            :Controller  => @_request.path_parameters['controller'],
            :Action      => @_request.path_parameters['action']
        }

        perform_action_without_oboe(*arguments)
        begin
          report_kvs[:Status] = @_response.status.to_i
        rescue
        end
        Oboe::API.log('rails', 'info', report_kvs)
      end

      def rescue_action(exn)
        Oboe::API.log_exception('rails', exn)
        rescue_action_without_oboe(exn)
      end

      def render(options = nil, extra_options = {}, &block)
        Oboe::API.trace('render', {}) do
          render_without_oboe(options, extra_options, &block)
        end
      end
    end
  end
  puts "[oboe/loading] Instrumenting ActionControler" if Oboe::Config[:verbose]
end
