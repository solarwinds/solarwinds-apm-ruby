# Copyright (c) 2013 AppNeta, Inc.
# All rights reserved.

module Oboe
  module Inst
    module Rails3ActionController
      def self.included(base)
        base.class_eval do
          alias_method_chain :process, :oboe
          alias_method_chain :process_action, :oboe
          alias_method_chain :render, :oboe
        end
      end
      
      def process_with_oboe(*args)
        Oboe::API.trace('rails', {}) do
          process_without_oboe *args
        end
      end

      def process_action_with_oboe(*args)
        report_kvs = {
          :Controller   => self.class.name,
          :Action       => self.action_name,
        }
        Oboe::API.log(nil, 'info', report_kvs)

        process_action_without_oboe *args
      rescue Exception => exception
        report_kvs[:Status] = 500
        Oboe::API.log(nil, 'info', report_kvs)
        raise
      end

      def render_with_oboe(*args)
        Oboe::API.trace('actionview', {}) do
          render_without_oboe *args
        end
      end
    end
    
    module Rails4ActionController
      def self.included(base)
        base.class_eval do
          alias_method_chain :process_action, :oboe
          alias_method_chain :render, :oboe
        end
      end
      
      def process_action_with_oboe(method_name, *args)
        report_kvs = {
          :Controller   => self.class.name,
          :Action       => self.action_name,
        }
        Oboe::API.trace('rails', report_kvs) do
          process_action_without_oboe(method_name, *args)
        end
      end

      def render_with_oboe(*args)
        Oboe::API.trace('actionview', {}) do
          render_without_oboe(*args)
        end
      end
    end
  end
end

if defined?(ActionController::Base) and Oboe::Config[:action_controller][:enabled]
  if ::Rails::VERSION::MAJOR == 4

    class ActionController::Base
      include Oboe::Inst::Rails4ActionController
    end
  
  elsif ::Rails::VERSION::MAJOR == 3

    class ActionController::Base
      include Oboe::Inst::Rails3ActionController
    end

  elsif ::Rails::VERSION::MAJOR == 2

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
            :Controller  => @_request.path_parameters['controller'],
            :Action      => @_request.path_parameters['action']
        }
        Oboe::API.log(nil, 'info', report_kvs)
        perform_action_without_oboe(*arguments)
      end

      def rescue_action(exn)
        Oboe::API.log_exception(nil, exn)
        rescue_action_without_oboe(exn)
      end

      def render(options = nil, extra_options = {}, &block)
        Oboe::API.trace('actionview', {}) do
          render_without_oboe(options, extra_options, &block)
        end
      end
    end
  end
  Oboe.logger.info "[oboe/loading] Instrumenting actioncontroler" if Oboe::Config[:verbose]
end
# vim:set expandtab:tabstop=2

