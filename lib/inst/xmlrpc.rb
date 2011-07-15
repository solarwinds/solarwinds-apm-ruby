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
          evt.addInfo("Layer", "XMLRPC")
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
            evt.addInfo("Layer", "ActiveRecord")
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
