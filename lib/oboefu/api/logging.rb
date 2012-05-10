# Copyright (c) 2012 by Tracelytics, Inc.
# All rights reserved.

module Oboe
  module API
    module Logging
      def log(layer, label, opts={})
        log_event(layer, label, Oboe::Context.createEvent, opts)
      end
  
      def log_exception(layer, exn)
        log(layer, 'error', {
          :ErrorClass => exn.class.name,
          :Message => exn.message,
          :ErrorBacktrace => exn.backtrace.join('\r\n')
        })
      end
  
      def log_start(layer, xtrace, opts={})
        return if Oboe::Config.never?
  
        if xtrace
          Oboe::Context.fromString(xtrace)
        end
  
        if Oboe::Config.tracing?
          self.log_entry(layer, opts)
        elsif Oboe::Config.start? and Oboe::Config.sample?
          self.log_event(layer, 'entry', Oboe::Context.startTrace, opts)
        end
      end
  
      def log_end(layer, opts={})
        log_event(layer, 'exit', Oboe::Context.createEvent, opts)
        xtrace = Oboe::Context.toString
        Oboe::Context.clear
        xtrace
      end
  
      def log_entry(layer, opts={})
        log_event(layer, 'entry', Oboe::Context.createEvent, opts)
      end
  
      def log_exit(layer, opts={})
        log_event(layer, 'exit', Oboe::Context.createEvent, opts)
      end
  
      def log_event(layer, label, event, opts={})
        event.addInfo('Layer', layer.to_s)
        event.addInfo('Label', label.to_s)
  
        (opts || {}).each do |k, v|
          event.addInfo(k.to_s, v.to_s) if valid_key? k
        end if opts.any?
  
        Oboe.reporter.sendReport(event)
      end
    end

    module LoggingNoop
      def log(layer, label, opts={})
        return
      end

      def log_exception(layer, exn)
        return
      end

      def log_start(layer, xtrace, opts={})
        return
      end

      def log_end(layer, opts={})
        return
      end

      def log_entry(layer, opts={})
        return
      end

      def log_exit(layer, opts={})
        return
      end

      def log_event(layer, label, event, opts={})
        return
      end
    end
  end 
end
