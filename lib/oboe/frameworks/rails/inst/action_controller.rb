# Copyright (c) 2012 by Tracelytics, Inc.
# All rights reserved.

module Oboe
  module Inst
    module Rails3ActionController
      def process(*args)

        header = request.headers['X-Trace']
        Oboe::API.start_trace_with_target('rails', header, response.headers) do
          super
        end
      end

      def process_action(*args)
        opts = {
          'HTTP-Host'   => @_request.headers['HTTP_HOST'],
          :URL          => @_request.headers['REQUEST_URI'],
          :Method       => @_request.headers['REQUEST_METHOD'],
          :Controller   => self.class.name,
          :Action       => self.action_name,
        }
        super

        opts[:Status] = @_response.status
        Oboe::API.log('rails', 'info', opts)
      
      rescue Exception => exception
        opts[:Status] = 500
        Oboe::API.log('rails', 'info', opts)
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

      def process(*args)
        header = args[0].headers['X-Trace']
        Oboe::API.start_trace_with_target('rails', header, args[1].headers) do
          process_without_oboe(*args)
        end
      end

      def perform_action(*arguments)
        opts = {
            'HTTP-Host'   => @_request.headers['HTTP_HOST'],
            :URL          => @_request.headers['REQUEST_URI'],
            :Method       => @_request.headers['REQUEST_METHOD'],
            :Status       => @_response.status,
            'Controller'  => @_request.path_parameters['controller'],
            'Action'      => @_request.path_parameters['action']
        }

        Oboe::API.log('rails', 'info', opts)
        perform_action_without_oboe(*arguments)
      end

      def rescue_action(exn)
        Oboe::API.log_exception('rails', exn)
        rescue_action_without_oboe(exn)
      end
    end
  end
  puts "[oboe/loading] Instrumenting ActionControler" if Oboe::Config[:verbose]
end
# vim:set expandtab:tabstop=2
