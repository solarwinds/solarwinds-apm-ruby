# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

if defined?(ActionView::Base) && AppOpticsAPM::Config[:action_view][:enabled]

  if Rails::VERSION::MAJOR == 2

    AppOpticsAPM.logger.info '[appoptics_apm/loading] Instrumenting actionview' if AppOpticsAPM::Config[:verbose]

    ActionView::Partials.module_eval do
      alias :render_partial_without_appoptics :render_partial
      def render_partial(options = {})
        if options.key?(:partial) && options[:partial].is_a?(String)
          entry_kvs = {}
          begin
            name  = AppOpticsAPM::Util.prettify(options[:partial]) if options.is_a?(Hash)
            entry_kvs[:FunctionName] = :render_partial
            entry_kvs[:Class]        = :Partials
            entry_kvs[:Module]       = :ActionView
            entry_kvs[:File]         = __FILE__
            entry_kvs[:LineNumber]   = __LINE__
          rescue => e
            AppOpticsAPM.logger.debug "[appoptics_apm/debug] #{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}" if AppOpticsAPM::Config[:verbose]
          end

          AppOpticsAPM::API.profile(name, entry_kvs, AppOpticsAPM::Config[:action_view][:collect_backtraces]) do
            render_partial_without_appoptics(options)
          end
        else
          render_partial_without_appoptics(options)
        end
      end

      alias :render_partial_collection_without_appoptics :render_partial_collection
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
          AppOpticsAPM.logger.debug "[appoptics_apm/debug] #{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}" if AppOpticsAPM::Config[:verbose]
        end

        AppOpticsAPM::API.profile(name, entry_kvs, AppOpticsAPM::Config[:action_view][:collect_backtraces]) do
          render_partial_collection_without_appoptics(options)
        end
      end
    end
  end
end

# vim:set expandtab:tabstop=2
