# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

if defined?(ActionView::Base) && AppOpticsAPM::Config[:action_view][:enabled]

  if Rails::VERSION::MAJOR == 3 && Rails::VERSION::MINOR == 0

    ActionView::Partials::PartialRenderer.class_eval do
      alias :render_partial_without_appoptics :render_partial
      def render_partial(object = @object)
        entry_kvs = {}
        begin
          name  = AppOpticsAPM::Util.prettify(@options[:partial]) if @options.is_a?(Hash)
          entry_kvs[:FunctionName] = :render_partial
          entry_kvs[:Class]        = :PartialRenderer
          entry_kvs[:Module]       = 'ActionView::Partials'
          entry_kvs[:File]         = __FILE__
          entry_kvs[:LineNumber]   = __LINE__
        rescue => e
          AppOpticsAPM.logger.debug "[appoptics_apm/debug] #{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}" if AppOpticsAPM::Config[:verbose]
        end

        AppOpticsAPM::API.profile(name, entry_kvs, AppOpticsAPM::Config[:action_view][:collect_backtraces]) do
          render_partial_without_appoptics(object)
        end
      end

      alias :render_collection_without_appoptics :render_collection
      def render_collection
        entry_kvs = {}
        begin
          name  = AppOpticsAPM::Util.prettify(@path)
          entry_kvs[:FunctionName] = :render_collection
          entry_kvs[:Class]        = :PartialRenderer
          entry_kvs[:Module]       = 'ActionView::Partials'
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
