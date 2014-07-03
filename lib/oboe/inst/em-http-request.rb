module Oboe
  module Inst
    module EventMachine
      module HttpConnection
        def setup_request_with_oboe(*args, &block)
          report_kvs = { Uri: @uri }
          report_kvs[:Backtrace] = Oboe::API.backtrace if Oboe::Config[:em_http_request][:collect_backtraces]

          ::Oboe::API.log_entry('em-http-request', report_kvs)
          client = setup_request_without_oboe(*args, &block)
          client.req.headers["X-Trace"] = Oboe::Context.toString()
          ::Oboe::API.log(nil, 'info', report_kvs)
          client.headers do |hash|
            ::Oboe::API.log_exit('em-http-request', { Async: 1 })
          end
          client
        end
      end
    end
  end
end

if defined?(::EventMachine::HttpConnection) and Oboe::Config[:em_http_request][:enabled]
  Oboe.logger.info "[oboe/loading] Instrumenting em-http-request" if Oboe::Config[:verbose]

  class ::EventMachine::HttpConnection
    include Oboe::Inst::EventMachine::HttpConnection

    if method_defined?(:setup_request)
      class_eval "alias :setup_request_without_oboe :setup_request"
      class_eval "alias :setup_request :setup_request_with_oboe"
    else 
      Oboe.logger.warn "[oboe/loading] Couldn't properly instrument em-http-request (:setup_request).  Partial traces may occur."
    end
  end
end
