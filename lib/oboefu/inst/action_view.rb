# Copyright (c) 2012 by Tracelytics, Inc.
# All rights reserved.

if defined?(ActionView::Base)
  if Rails::VERSION::MAJOR == 3
    Oboe::API.report_init('rails')
    puts "[oboe_fu/loading] Instrumenting ActionView" 
    
    ActionView::PartialRenderer.class_eval do
      alias :render_without_oboe :render
      def render(context, options, block)
        opts = {}
        opts[:partial] = options[:partial] if options.has_key?(:partial)
        opts[:file] = options[:file] if options.has_key?(:file)

        Oboe::API.trace('partial', opts) do
          render_without_oboe(context, options, block)
        end
      end
    end
  elsif Rails::VERSION::MAJOR == 2
    Oboe::API.report_init('rails')
    puts "[oboe_fu/loading] Instrumenting ActionView" 

    ActionView::Helpers::RenderingHelper.module_eval do
      alias :render_without_oboe :render
    
      def render(options = {}, locals = {}, &block)
        opts = {}
        puts options.inspect
        opts[:partial] = options[:partial] if options.has_key?(:partial)
        opts[:file] = options[:file] if options.has_key?(:file)

        Oboe::API.start_trace_with_target('render', opts) do
          render_without_oboe(options, locals, &block)
        end
      end

    end
  end
end
# vim:set expandtab:tabstop=2
