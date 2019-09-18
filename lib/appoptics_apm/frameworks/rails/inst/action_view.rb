# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

if defined?(ActionView::Base) && AppOpticsAPM::Config[:action_view][:enabled]  && Rails::VERSION::MAJOR < 6

  ##
  # ActionView Instrumentation is version dependent.  ActionView 2.x is separate
  # and ActionView 3.0 is a special case.
  # Everything else goes here. (ActionView 3.1 - 4.0 as of this writing)
  #
  if Rails::VERSION::MAJOR >= 4

    AppOpticsAPM.logger.info '[appoptics_apm/loading] Instrumenting actionview' if AppOpticsAPM::Config[:verbose]

    ActionView::PartialRenderer.class_eval do
      alias :render_partial_without_appoptics :render_partial
      def render_partial
        entry_kvs = {}
        begin
          name = AppOpticsAPM::Util.prettify(@options[:partial]) if @options.is_a?(Hash)
          entry_kvs[:FunctionName] = :render_partial
          entry_kvs[:Class]        = :PartialRenderer
          entry_kvs[:Module]       = :ActionView
          entry_kvs[:File]         = __FILE__
          entry_kvs[:LineNumber]   = __LINE__
        rescue => e
          AppOpticsAPM.logger.debug "[appoptics_apm/debug] #{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}" if AppOpticsAPM::Config[:verbose]
        end

        AppOpticsAPM::API.profile(name, entry_kvs, AppOpticsAPM::Config[:action_view][:collect_backtraces]) do
          render_partial_without_appoptics
        end
      end

      alias :render_collection_without_appoptics :render_collection
      def render_collection
        entry_kvs = {}
        begin
          name = AppOpticsAPM::Util.prettify(@path)
          entry_kvs[:FunctionName] = :render_collection
          entry_kvs[:Class]        = :PartialRenderer
          entry_kvs[:Module]       = :ActionView
          entry_kvs[:File]         = __FILE__
          entry_kvs[:LineNumber]   = __LINE__
        rescue => e
          AppOpticsAPM.logger.debug "[appoptics_apm/debug] #{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}" if AppOpticsAPM::Config[:verbose]
        end

        AppOpticsAPM::API.profile(name, entry_kvs, AppOpticsAPM::Config[:action_view][:collect_backtraces]) do
          render_collection_without_appoptics
        end
      end

    end
  end
end

# vim:set expandtab:tabstop=2
