# Copyright (c) 2012 by Tracelytics, Inc.
# All rights reserved.

if defined?(ActionView::Base) and Oboe::Config[:action_view][:enabled]

  if Rails::VERSION::MAJOR == 3
    puts "[oboe/loading] Instrumenting actionview" if Oboe::Config[:verbose]

    if Rails::VERSION::MINOR == 0
      ActionView::Partials::PartialRenderer.class_eval do
        alias :render_partial_without_oboe :render_partial
        def render_partial(object = @object)
          entry_kvs = {}
          begin
            entry_kvs[:Language]     = :ruby
            entry_kvs[:ProfileName]  = @options[:partial] if @options.is_a?(Hash)
            entry_kvs[:FunctionName] = :render_partial
            entry_kvs[:Class]        = :PartialRenderer
            entry_kvs[:Module]       = 'ActionView::Partials'
            entry_kvs[:File]         = __FILE__
            entry_kvs[:LineNumber]   = __LINE__
          rescue
          end

          Oboe::Context.log(nil, 'profile_entry', entry_kvs)
          ret =  render_partial_without_oboe(object)

          exit_kvs = {}
          begin
            exit_kvs[:Language] = :ruby
            exit_kvs[:ProfileName]  = @options[:partial] if @options.is_a?(Hash)
          rescue
          end

          Oboe::Context.log(nil, 'profile_exit', exit_kvs, false)
          ret
        end
        
        alias :render_collection_without_oboe :render_collection
        def render_collection
          entry_kvs = {}
          begin
            entry_kvs[:Language]     = :ruby
            entry_kvs[:ProfileName]  = @path
            entry_kvs[:FunctionName] = :render_collection
            entry_kvs[:Class]        = :PartialRenderer
            entry_kvs[:Module]       = 'ActionView::Partials'
            entry_kvs[:File]         = __FILE__
            entry_kvs[:LineNumber]   = __LINE__
          rescue
          end

          Oboe::Context.log(nil, 'profile_entry', entry_kvs)
          ret =  render_collection_without_oboe

          exit_kvs = {}
          begin
            exit_kvs[:Language] = :ruby
            exit_kvs[:ProfileName]  = @path
          rescue
          end

          Oboe::Context.log(nil, 'profile_exit', exit_kvs, false)
          ret
        end
      end
    else
      ActionView::PartialRenderer.class_eval do
        alias :render_partial_without_oboe :render_partial
        def render_partial
          entry_kvs = {}
          begin
            entry_kvs[:Language]     = :ruby
            entry_kvs[:ProfileName]  = @options[:partial] if @options.is_a?(Hash)
            entry_kvs[:FunctionName] = :render_partial
            entry_kvs[:Class]        = :PartialRenderer
            entry_kvs[:Module]       = :ActionView
            entry_kvs[:File]         = __FILE__
            entry_kvs[:LineNumber]   = __LINE__
          rescue
          end

          Oboe::Context.log(nil, 'profile_entry', entry_kvs)
          ret =  render_partial_without_oboe

          exit_kvs = {}
          begin
            exit_kvs[:Language] = :ruby
            exit_kvs[:ProfileName]  = @options[:partial] if @options.is_a?(Hash)
          rescue
          end

          Oboe::Context.log(nil, 'profile_exit', exit_kvs, false)
          ret
        end

        alias :render_collection_without_oboe :render_collection
        def render_collection
          entry_kvs = {}
          begin
            entry_kvs[:Language]     = :ruby
            entry_kvs[:ProfileName]  = @path
            entry_kvs[:FunctionName] = :render_collection
            entry_kvs[:Class]        = :PartialRenderer
            entry_kvs[:Module]       = :ActionView
            entry_kvs[:File]         = __FILE__
            entry_kvs[:LineNumber]   = __LINE__
          rescue
          end

          Oboe::Context.log(nil, 'profile_entry', entry_kvs)
          ret =  render_collection_without_oboe

          exit_kvs = {}
          begin
            exit_kvs[:Language] = :ruby
            exit_kvs[:ProfileName]  = @path
          rescue
          end

          Oboe::Context.log(nil, 'profile_exit', exit_kvs, false)
          ret
        end
      end
    end
  elsif Rails::VERSION::MAJOR == 2
    puts "[oboe/loading] Instrumenting actionview" if Oboe::Config[:verbose]

    ActionView::Partials.module_eval do
      alias :render_partial_without_oboe :render_partial
      def render_partial(options = {})
        if options.has_key?(:partial) and options[:partial].is_a?(String)
          entry_kvs = {}
          begin
            entry_kvs[:Language]     = :ruby
            entry_kvs[:ProfileName]  = options[:partial]
            entry_kvs[:FunctionName] = :render_partial
            entry_kvs[:Class]        = :Partials
            entry_kvs[:Module]       = :ActionView
            entry_kvs[:File]         = __FILE__
            entry_kvs[:LineNumber]   = __LINE__
          rescue
          end

          Oboe::Context.log(nil, 'profile_entry', entry_kvs)
          ret = render_partial_without_oboe(options)

          exit_kvs = {}
          begin
            exit_kvs[:Language] = :ruby
            exit_kvs[:ProfileName] = options[:partial]
          rescue
          end

          Oboe::Context.log(nil, 'profile_exit', exit_kvs, false)
        else
          ret = render_partial_without_oboe(options)
        end
        ret
      end
      
      alias :render_partial_collection_without_oboe :render_partial_collection
      def render_partial_collection(options = {})
        entry_kvs = {}
        begin
          entry_kvs[:Language]     = :ruby
          entry_kvs[:ProfileName]  = :collection
          entry_kvs[:FunctionName] = :render_partial_collection
          entry_kvs[:Class]        = :Partials
          entry_kvs[:Module]       = :ActionView
          entry_kvs[:File]         = __FILE__
          entry_kvs[:LineNumber]   = __LINE__
        rescue
        end

        Oboe::Context.log(nil, 'profile_entry', entry_kvs)
        ret =  render_partial_collection_without_oboe(options)

        exit_kvs = {}
        begin
          exit_kvs[:Language] = :ruby
          exit_kvs[:ProfileName] = :collection
        rescue
        end

        Oboe::Context.log(nil, 'profile_exit', exit_kvs, false)
        ret
      end
    end
  end
end
# vim:set expandtab:tabstop=2
