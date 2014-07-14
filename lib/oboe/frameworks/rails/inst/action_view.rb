# Copyright (c) 2013 AppNeta, Inc.
# All rights reserved.

if defined?(ActionView::Base) and Oboe::Config[:action_view][:enabled]

  ##
  # ActionView Instrumentation is version dependent.  ActionView 2.x is separate
  # and ActionView 3.0 is a special case.
  # Everything else goes here. (ActionView 3.1 - 4.0 as of this writing)
  #
  if (Rails::VERSION::MAJOR == 3 and Rails::VERSION::MINOR > 0) or Rails::VERSION::MAJOR == 4

    Oboe.logger.info "[oboe/loading] Instrumenting actionview" if Oboe::Config[:verbose]

    ActionView::PartialRenderer.class_eval do
      alias :render_partial_without_oboe :render_partial
      def render_partial
        entry_kvs = {}
        begin
          name = Oboe::Util.prettify(@options[:partial]) if @options.is_a?(Hash)
          entry_kvs[:FunctionName] = :render_partial
          entry_kvs[:Class]        = :PartialRenderer
          entry_kvs[:Module]       = :ActionView
          entry_kvs[:File]         = __FILE__
          entry_kvs[:LineNumber]   = __LINE__
        rescue
        end

        Oboe::API.profile(name, entry_kvs, Oboe::Config[:action_view][:collect_backtraces]) do
          render_partial_without_oboe
        end
      end

      alias :render_collection_without_oboe :render_collection
      def render_collection
        entry_kvs = {}
        begin
          name = Oboe::Util.prettify(@path)
          entry_kvs[:FunctionName] = :render_collection
          entry_kvs[:Class]        = :PartialRenderer
          entry_kvs[:Module]       = :ActionView
          entry_kvs[:File]         = __FILE__
          entry_kvs[:LineNumber]   = __LINE__
        rescue
        end

        Oboe::API.profile(name, entry_kvs, Oboe::Config[:action_view][:collect_backtraces]) do
          ret =  render_collection_without_oboe
        end
      end

    end
  end
end

# vim:set expandtab:tabstop=2
