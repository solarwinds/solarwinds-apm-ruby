# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

if defined?(ActionView::Base) && AppOptics::Config[:action_view][:enabled]

  ##
  # ActionView Instrumentation is version dependent.  ActionView 2.x is separate
  # and ActionView 3.0 is a special case.
  # Everything else goes here. (ActionView 3.1 - 4.0 as of this writing)
  #
  if (Rails::VERSION::MAJOR == 3 && Rails::VERSION::MINOR > 0) || Rails::VERSION::MAJOR >= 4

    AppOptics.logger.info '[appoptics/loading] Instrumenting actionview' if AppOptics::Config[:verbose]

    ActionView::PartialRenderer.class_eval do
      alias :render_partial_without_appoptics :render_partial
      def render_partial
        entry_kvs = {}
        begin
          name = AppOptics::Util.prettify(@options[:partial]) if @options.is_a?(Hash)
          entry_kvs[:FunctionName] = :render_partial
          entry_kvs[:Class]        = :PartialRenderer
          entry_kvs[:Module]       = :ActionView
          entry_kvs[:File]         = __FILE__
          entry_kvs[:LineNumber]   = __LINE__
        rescue => e
          AppOptics.logger.debug "[appoptics/debug] #{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}" if AppOptics::Config[:verbose]
        end

        AppOptics::API.profile(name, entry_kvs, AppOptics::Config[:action_view][:collect_backtraces]) do
          render_partial_without_appoptics
        end
      end

      alias :render_collection_without_appoptics :render_collection
      def render_collection
        entry_kvs = {}
        begin
          name = AppOptics::Util.prettify(@path)
          entry_kvs[:FunctionName] = :render_collection
          entry_kvs[:Class]        = :PartialRenderer
          entry_kvs[:Module]       = :ActionView
          entry_kvs[:File]         = __FILE__
          entry_kvs[:LineNumber]   = __LINE__
        rescue => e
          AppOptics.logger.debug "[appoptics/debug] #{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}" if AppOptics::Config[:verbose]
        end

        AppOptics::API.profile(name, entry_kvs, AppOptics::Config[:action_view][:collect_backtraces]) do
          render_collection_without_appoptics
        end
      end

    end
  end
end

# vim:set expandtab:tabstop=2
