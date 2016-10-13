# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

if defined?(ActionView::Base) && TraceView::Config[:action_view][:enabled]

  if Rails::VERSION::MAJOR == 2

    TraceView.logger.info '[traceview/loading] Instrumenting actionview' if TraceView::Config[:verbose]

    ActionView::Partials.module_eval do
      alias :render_partial_without_traceview :render_partial
      def render_partial(options = {})
        if options.key?(:partial) && options[:partial].is_a?(String)
          entry_kvs = {}
          begin
            name  = TraceView::Util.prettify(options[:partial]) if options.is_a?(Hash)
            entry_kvs[:FunctionName] = :render_partial
            entry_kvs[:Class]        = :Partials
            entry_kvs[:Module]       = :ActionView
            entry_kvs[:File]         = __FILE__
            entry_kvs[:LineNumber]   = __LINE__
          rescue => e
            TraceView.logger.debug "[traceview/debug] #{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}" if TraceView::Config[:verbose]
          end

          TraceView::API.profile(name, entry_kvs, TraceView::Config[:action_view][:collect_backtraces]) do
            render_partial_without_traceview(options)
          end
        else
          render_partial_without_traceview(options)
        end
      end

      alias :render_partial_collection_without_traceview :render_partial_collection
      def render_partial_collection(options = {})
        entry_kvs = {}
        begin
          name  = 'partial_collection'
          entry_kvs[:FunctionName] = :render_partial_collection
          entry_kvs[:Class]        = :Partials
          entry_kvs[:Module]       = :ActionView
          entry_kvs[:File]         = __FILE__
          entry_kvs[:LineNumber]   = __LINE__
        rescue => e
          TraceView.logger.debug "[traceview/debug] #{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}" if TraceView::Config[:verbose]
        end

        TraceView::API.profile(name, entry_kvs, TraceView::Config[:action_view][:collect_backtraces]) do
          render_partial_collection_without_traceview(options)
        end
      end
    end
  end
end

# vim:set expandtab:tabstop=2
