# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

if defined?(ActionView::Base) && AppOptics::Config[:action_view][:enabled]

  if Rails::VERSION::MAJOR == 2

    AppOptics.logger.info '[appoptics/loading] Instrumenting actionview' if AppOptics::Config[:verbose]

    ActionView::Partials.module_eval do
      alias :render_partial_without_appoptics :render_partial
      def render_partial(options = {})
        if options.key?(:partial) && options[:partial].is_a?(String)
          entry_kvs = {}
          begin
            name  = AppOptics::Util.prettify(options[:partial]) if options.is_a?(Hash)
            entry_kvs[:FunctionName] = :render_partial
            entry_kvs[:Class]        = :Partials
            entry_kvs[:Module]       = :ActionView
            entry_kvs[:File]         = __FILE__
            entry_kvs[:LineNumber]   = __LINE__
          rescue => e
            AppOptics.logger.debug "[appoptics/debug] #{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}" if AppOptics::Config[:verbose]
          end

          AppOptics::API.profile(name, entry_kvs, AppOptics::Config[:action_view][:collect_backtraces]) do
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
          AppOptics.logger.debug "[appoptics/debug] #{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}" if AppOptics::Config[:verbose]
        end

        AppOptics::API.profile(name, entry_kvs, AppOptics::Config[:action_view][:collect_backtraces]) do
          render_partial_collection_without_appoptics(options)
        end
      end
    end
  end
end

# vim:set expandtab:tabstop=2
