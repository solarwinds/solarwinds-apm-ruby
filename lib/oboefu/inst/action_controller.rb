# Copyright (c) 2012 by Tracelytics, Inc.
# All rights reserved.

module OboeFu
  module Inst
    module Rails3ActionController
      def process(*args)
        header = request.headers['X-Trace']
        result, header = Oboe::Inst.trace_start_layer_block('rails', header) do |exitEvent|
          response.headers['X-Trace'] = exitEvent.metadataString() if exitEvent
          super
        end

        result
      end

      def process_action(*args)
        opts = {
          'HTTP-Host' => @_request.headers['HTTP_HOST'],
          :URL        => @_request.headers['REQUEST_URI'],
          :Method     => @_request.headers['REQUEST_METHOD'],
          :Status     => @_response.status,
          :Controller => self.class.name,
          :Action     => self.action_name,
        }
        Oboe::Inst.log('rails', 'info', opts)

        super
      end

      def render(*args)
        Oboe::Inst.trace_layer_block('render', {}) do
          super
        end
      end
    end
  end
end

if defined?(ActionController::Base)
  if Rails::VERSION::MAJOR == 3
    class ActionController::Base
      include OboeFu::Inst::Rails3ActionController
    end
  elsif Rails::VERSION::MAJOR == 2
    ActionController::Base.class_eval do
      alias :old_perform_action :perform_action
      alias :old_rescue_action :rescue_action
      alias :old_process :process

      def process(request, response)
        header = request.headers['X-Trace']
        result, header = Oboe::Inst.trace_start_layer_block('rails', header) do |exitEvent|
          response.headers['X-Trace'] = exitEvent.metadataString() if exitEvent
          old_process(request, response)
        end

        result
      end

      def perform_action(*arguments)
        opts = {
            'HTTP-Host'  => @_request.headers['HTTP_HOST'],
            'URL'        => @_request.headers['REQUEST_URI'],
            'Method'     => @_request.headers['REQUEST_METHOD'],
            'Status'     => @_response.status,
            'Controller' => @_request.path_parameters['controller'],
            'Action'     => @_request.path_parameters['action']
        }
        Oboe::Inst.log('rails', 'info', opts)

        old_perform_action(*arguments)
      end

      def rescue_action(exn)
        Oboe::Inst.log_exception('rails', exn)
        old_rescue_action(exn)
      end
    end
  end
end
