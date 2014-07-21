# Copyright (c) 2013 AppNeta, Inc.
# All rights reserved.

if defined?(ActionView::Base) and Oboe::Config[:action_view][:enabled]

  if Rails::VERSION::MAJOR == 2

    Oboe.logger.info "[oboe/loading] Instrumenting actionview" if Oboe::Config[:verbose]

    ActionView::Partials.module_eval do
      alias :render_partial_without_oboe :render_partial
      def render_partial(options = {})
        if options.has_key?(:partial) and options[:partial].is_a?(String)
          entry_kvs = {}
          begin
            name  = Oboe::Util.prettify(options[:partial]) if options.is_a?(Hash)
            entry_kvs[:FunctionName] = :render_partial
            entry_kvs[:Class]        = :Partials
            entry_kvs[:Module]       = :ActionView
            entry_kvs[:File]         = __FILE__
            entry_kvs[:LineNumber]   = __LINE__
          rescue
          end

          Oboe::API.profile(name, entry_kvs, Oboe::Config[:action_view][:collect_backtraces]) do
            render_partial_without_oboe(options)
          end
        else
          render_partial_without_oboe(options)
        end
      end

      alias :render_partial_collection_without_oboe :render_partial_collection
      def render_partial_collection(options = {})
        entry_kvs = {}
        begin
          name  = "partial_collection"
          entry_kvs[:FunctionName] = :render_partial_collection
          entry_kvs[:Class]        = :Partials
          entry_kvs[:Module]       = :ActionView
          entry_kvs[:File]         = __FILE__
          entry_kvs[:LineNumber]   = __LINE__
        rescue
        end

        Oboe::API.profile(name, entry_kvs, Oboe::Config[:action_view][:collect_backtraces]) do
          render_partial_collection_without_oboe(options)
        end
      end
    end
  end
end

# vim:set expandtab:tabstop=2
