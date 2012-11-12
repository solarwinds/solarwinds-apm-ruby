# Copyright (c) 2012 by Tracelytics, Inc.
# All rights reserved.

if defined?(ActionView::Base)
  if Rails::VERSION::MAJOR == 3
    puts "[oboe/loading] Instrumenting ActionView" 

    if Rails::VERSION::MINOR == 0
      ActionView::Partials::PartialRenderer.class_eval do
        alias :render_partial_without_oboe :render_partial
        def render_partial(object = @object)
          report_kvs = {}
          begin
            report_kvs[:partial] = @options[:partial] if @options.is_a?(Hash)
            report_kvs[:file] = @template.inspect if @template
          rescue
          end

          Oboe::API.trace('partial', report_kvs) do
            render_partial_without_oboe(object)
          end
        end
      end
    else
      ActionView::PartialRenderer.class_eval do
        alias :render_without_oboe :render
        def render(context, options, block)
          report_kvs = {}
          begin
            report_kvs[:partial] = options[:partial] if options.has_key?(:partial)
            report_kvs[:file] = options[:file] if options.has_key?(:file)
          rescue
          end

          Oboe::API.trace('partial', report_kvs) do
            render_without_oboe(context, options, block)
          end
        end
      end
    end
  elsif Rails::VERSION::MAJOR == 2
    puts "[oboe/loading] Instrumenting ActionView" 

    ActionView::Partials.module_eval do
      alias :render_partial_without_oboe :render_partial
    
      def render_partial(options = {})
        report_kvs = {}
        begin
          report_kvs[:partial] = options[:partial] if options.has_key?(:partial)
        rescue
        end

        Oboe::API.trace('partial', report_kvs) do
          render_partial_without_oboe(options)
        end
      end

    end
  end
end
# vim:set expandtab:tabstop=2
