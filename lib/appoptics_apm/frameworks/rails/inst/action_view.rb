# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

if defined?(ActionView::Base) && SolarWindsAPM::Config[:action_view][:enabled]

  if Rails::VERSION::MAJOR >= 4

    SolarWindsAPM.logger.info '[appoptics_apm/loading] Instrumenting actionview' if SolarWindsAPM::Config[:verbose]
    if ActionView.version >= Gem::Version.new('6.1.0') # the methods changed in this version

      ActionView::PartialRenderer.class_eval do
        alias :render_partial_template_without_appoptics :render_partial_template

        def render_partial_template(*args)
          _, _, template, _, _ = args
          entry_kvs = {}
          begin
            entry_kvs[:Partial] = template.virtual_path
          rescue => e
            SolarWindsAPM.logger.debug "[appoptics_apm/debug] #{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}" if SolarWindsAPM::Config[:verbose]
          end
          SolarWindsAPM::SDK.trace(:partial, kvs: entry_kvs) do
            entry_kvs[:Backtrace] = SolarWindsAPM::API.backtrace if SolarWindsAPM::Config[:action_view][:collect_backtraces]
            render_partial_template_without_appoptics(*args)
          end
        end
      end

      ActionView::CollectionRenderer.class_eval do
        alias :render_collection_without_appoptics :render_collection

        def render_collection(*args)
          _, _, _, template, _, _ = args
          entry_kvs = {}
          begin
            entry_kvs[:Partial] = template.virtual_path
          rescue => e
            SolarWindsAPM.logger.debug "[appoptics_apm/debug] #{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}" if SolarWindsAPM::Config[:verbose]
          end
          SolarWindsAPM::SDK.trace(:collection, kvs: entry_kvs) do
            entry_kvs[:Backtrace] = SolarWindsAPM::API.backtrace if SolarWindsAPM::Config[:action_view][:collect_backtraces]
            render_collection_without_appoptics(*args)
          end
        end
      end

    else # Rails < 6.1.0

      ActionView::PartialRenderer.class_eval do
        alias :render_partial_without_appoptics :render_partial
        def render_partial(*args)
          template = @template || args[1]
          entry_kvs = {}
          begin
            entry_kvs[:Partial] = template.virtual_path
            # entry_kvs[:Partial] = SolarWindsAPM::Util.prettify(@options[:partial]) if @options.is_a?(Hash)
          rescue => e
            SolarWindsAPM.logger.debug "[appoptics_apm/debug] #{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}" if SolarWindsAPM::Config[:verbose]
          end

          SolarWindsAPM::SDK.trace('partial', kvs: entry_kvs) do
            entry_kvs[:Backtrace] = SolarWindsAPM::API.backtrace if SolarWindsAPM::Config[:action_view][:collect_backtraces]
            render_partial_without_appoptics(*args)
          end
        end

        alias :render_collection_without_appoptics :render_collection
        def render_collection(*args)
          template = @template || args[1]
          entry_kvs = {}
          begin
            entry_kvs[:Partial] = template.virtual_path
          rescue => e
            SolarWindsAPM.logger.debug "[appoptics_apm/debug] #{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}" if SolarWindsAPM::Config[:verbose]
          end

          SolarWindsAPM::SDK.trace('collection', kvs: entry_kvs) do
            entry_kvs[:Backtrace] = SolarWindsAPM::API.backtrace if SolarWindsAPM::Config[:action_view][:collect_backtraces]
            render_collection_without_appoptics(*args)
          end
        end
      end

    end
  end
end

# vim:set expandtab:tabstop=2
