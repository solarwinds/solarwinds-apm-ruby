# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

if defined?(ActionView::Base) && TraceView::Config[:action_view][:enabled]

  ##
  # ActionView Instrumentation is version dependent.  ActionView 2.x is separate
  # and ActionView 3.0 is a special case.
  # Everything else goes here. (ActionView 3.1 - 4.0 as of this writing)
  #
  if (Rails::VERSION::MAJOR == 3 && Rails::VERSION::MINOR > 0) || Rails::VERSION::MAJOR >= 4

    TraceView.logger.info '[traceview/loading] Instrumenting actionview' if TraceView::Config[:verbose]

    ActionView::PartialRenderer.class_eval do
      alias :render_partial_without_traceview :render_partial
      def render_partial
        entry_kvs = {}
        begin
          name = TraceView::Util.prettify(@options[:partial]) if @options.is_a?(Hash)
          entry_kvs[:FunctionName] = :render_partial
          entry_kvs[:Class]        = :PartialRenderer
          entry_kvs[:Module]       = :ActionView
          entry_kvs[:File]         = __FILE__
          entry_kvs[:LineNumber]   = __LINE__
        rescue => e
          TraceView.logger.debug "[traceview/debug] #{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}" if TraceView::Config[:verbose]
        end

        TraceView::API.profile(name, entry_kvs, TraceView::Config[:action_view][:collect_backtraces]) do
          render_partial_without_traceview
        end
      end

      alias :render_collection_without_traceview :render_collection
      def render_collection
        entry_kvs = {}
        begin
          name = TraceView::Util.prettify(@path)
          entry_kvs[:FunctionName] = :render_collection
          entry_kvs[:Class]        = :PartialRenderer
          entry_kvs[:Module]       = :ActionView
          entry_kvs[:File]         = __FILE__
          entry_kvs[:LineNumber]   = __LINE__
        rescue => e
          TraceView.logger.debug "[traceview/debug] #{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}" if TraceView::Config[:verbose]
        end

        TraceView::API.profile(name, entry_kvs, TraceView::Config[:action_view][:collect_backtraces]) do
          render_collection_without_traceview
        end
      end

    end
  end
end

# vim:set expandtab:tabstop=2
