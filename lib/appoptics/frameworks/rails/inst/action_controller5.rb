# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

module AppOptics
  module Inst
    #
    # ActionController
    #
    # This modules contains the instrumentation code specific
    # to Rails v5
    #
    module ActionController
      include ::AppOptics::Inst::RailsBase

      def process_action(method_name, *args)
        kvs = {
            :Controller   => self.class.name,
            :Action       => self.action_name,
        }
        request.env['appoptics.transaction'] = "#{kvs[:Controller]}.#{kvs[:Action]}"

        return super(method_name, *args) unless AppOptics.tracing?
        begin
          kvs[:Backtrace] = AppOptics::API.backtrace if AppOptics::Config[:action_controller][:collect_backtraces]

          AppOptics::API.log_entry('rails', kvs)
          super(method_name, *args)

        rescue Exception => e
          AppOptics::API.log_exception(nil, e) if log_rails_error?(e)
          raise
        ensure
          AppOptics::API.log_exit('rails')
        end
      end

      #
      # render
      #
      # Our render wrapper that calls 'trace', which will log if we are tracing
      #
      def render(*args, &blk)
        trace('actionview') do
          super(*args, &blk)
        end
      end
    end
  end
end
