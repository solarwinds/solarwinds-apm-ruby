class ActionController::Base
  alias old_process process

  def process(request, response, *arguments)
    Oboe::Context.clear()

    xtr_hdr = request.headers['X-Trace']
    evt = nil
    endEvt = nil

    tracing_mode = Oboe::Config[:tracing_mode]

    if xtr_hdr and ["always", "through"].include?(tracing_mode)
      Oboe::Context.fromString(xtr_hdr)
    end

    if not Oboe::Context.isValid() and tracing_mode == "always"
      evt = Oboe::Context.startTrace()
    elsif Oboe::Context.isValid() and tracing_mode != "never"
      evt = Oboe::Context.createEvent()
    end

    if Oboe::Context.isValid() and tracing_mode != "never"
      evt.addInfo("Agent", "rails")
      evt.addInfo("Label", "entry")

      request.path_parameters.each_pair do |k, v|
        evt.addInfo(k.to_s.capitalize, v.to_s)
      end

      Oboe.reporter.sendReport(evt)

      endEvt = Oboe::Context.createEvent()
    end

    begin
      result = send(:old_process, request, response, *arguments)
    ensure
      # TODO: Should we handle starting a trace here?
      if Oboe::Context.isValid() and tracing_mode != "never" and endEvt
        evt = endEvt

        evt.addEdge(Oboe::Context.get())
        evt.addInfo("Agent", "rails")
        evt.addInfo("Label", "exit")

        request.path_parameters.each_pair do |k, v|
          evt.addInfo(k.to_s.capitalize, v.to_s)
        end

        Oboe.reporter.sendReport(evt)

        response.headers['X-Trace'] = Oboe::Context.toString()
        endEvt = nil

        Oboe::Context.clear()
      end
    end

    return result
  end
end

ActiveRecord::Base.class_eval do
  class << self
    alias old_find_by_sql find_by_sql

    def find_by_sql(query, *arguments)
      tracing_mode = Oboe::Config[:tracing_mode]

      if Oboe::Context.isValid() and tracing_mode != "never"
        evt = Oboe::Context.createEvent()
        evt.addInfo("Agent", "ActiveRecord")
        evt.addInfo("Label", "entry")
        evt.addInfo("Query",  query.to_s)

        evt.addInfo("Backtrace", Kernel.caller.join("\r\n"))

        Oboe.reporter.sendReport(evt)
      end

      begin
        result = old_find_by_sql(query, *arguments)
      ensure
        if Oboe::Context.isValid() and tracing_mode != "never"
          evt = Oboe::Context.createEvent()
          evt.addInfo("Agent", "ActiveRecord")
          evt.addInfo("Label", "exit")

          Oboe.reporter.sendReport(evt)
        end
      end

      return result
    end
  end
end

require 'xmlrpc/client'

module XMLRPC
  class Client
    alias old_call2 call2
    alias old_call2_async call2_async

    alias old_muticall2 multicall2
    alias old_multicall2_async multicall2_async

    [:call2, :call2_async, :multicall2, :multicall2_async].each do |m|
      define_method(m) do |method, *args|
        tracing_mode = Oboe::Config[:tracing_mode]

        if Oboe::Context.isValid() and tracing_mode != "never"
          evt = Oboe::Context.createEvent()
          evt.addInfo("Agent", "XMLRPC")
          evt.addInfo("Label", "entry")
          evt.addInfo("Method",  method.to_s)

          evt.addInfo("Backtrace", Kernel.caller.join("\r\n"))

          Oboe.reporter.sendReport(evt)

          @http_header_extra = {} unless http_header_extra
          @http_header_extra['X-Trace'] = Oboe::Context.toString()
        end

        begin 
          result = send("old_#{m}", method, *args)
        ensure
          if Oboe::Context.isValid() and tracing_mode != "never"
            if @http_last_response and @http_last_response['X-Trace']
              Oboe::Context.fromString(@http_last_response['X-Trace'])
            end

            evt = Oboe::Context.createEvent()
            evt.addInfo("Agent", "ActiveRecord")
            evt.addInfo("Label", "exit")
            evt.addInfo("Method", method.to_s)
  
            Oboe.reporter.sendReport(evt)
          end
        end

        result
      end
    end

  end
end
