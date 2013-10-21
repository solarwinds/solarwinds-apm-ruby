# Copyright (c) 2013 AppNeta, Inc.
# All rights reserved.

if defined?(ActionView::Base) and Oboe::Config[:action_view][:enabled]

  if Rails::VERSION::MAJOR == 3 and Rails::VERSION::MINOR == 0

    ActionView::Partials::PartialRenderer.class_eval do
      alias :render_partial_without_oboe :render_partial
      def render_partial(object = @object)
        entry_kvs = {}
        begin
          name  = @options[:partial].to_s if @options.is_a?(Hash)
          entry_kvs[:FunctionName] = :render_partial
          entry_kvs[:Class]        = :PartialRenderer
          entry_kvs[:Module]       = 'ActionView::Partials'
          entry_kvs[:File]         = __FILE__
          entry_kvs[:LineNumber]   = __LINE__
        rescue
        end

        Oboe::API.profile(name, entry_kvs) do
          render_partial_without_oboe(object)
        end
      end
      
      alias :render_collection_without_oboe :render_collection
      def render_collection
        entry_kvs = {}
        begin
          name  = @path
          entry_kvs[:FunctionName] = :render_collection
          entry_kvs[:Class]        = :PartialRenderer
          entry_kvs[:Module]       = 'ActionView::Partials'
          entry_kvs[:File]         = __FILE__
          entry_kvs[:LineNumber]   = __LINE__
        rescue
        end

        Oboe::API.profile(name, entry_kvs) do
          render_collection_without_oboe
        end
      end
    end
  end
end

# vim:set expandtab:tabstop=2
