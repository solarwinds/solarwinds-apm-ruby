module Oboe
  module Inst
    module EventMachine
      module HttpConnection
        def setup_request_with_oboe(*args, &block)
          report_kvs = { :Uri => @uri }
          report_kvs[:Backtrace] = Oboe::API.backtrace if Oboe::Config[:em_http_request][:collect_backtraces]

          ::Oboe::API.log_entry('em-http-request', report_kvs)
          client = setup_request_without_oboe(*args, &block)
          client.req.headers["X-Trace"] = Oboe::Context.toString()
          ::Oboe::API.log(nil, 'info', report_kvs)
          client
        end
      end

      module HttpClient
        def parse_response_header_with_oboe(*args, &block)
          ::Oboe::API.log_exit('em-http-request', { :Async => 1 })
          parse_response_header_without_oboe(*args, &block)
        end
      end
    end
  end
end

if defined?(::EventMachine::HttpConnection) and defined?(::EventMachine::HttpClient) and Oboe::Config[:em_http_request][:enabled]
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

  class ::EventMachine::HttpClient
    include Oboe::Inst::EventMachine::HttpClient

    if method_defined?(:parse_response_header)
      class_eval "alias :parse_response_header_without_oboe :parse_response_header"
      class_eval "alias :parse_response_header :parse_response_header_with_oboe"
    else
      Oboe.logger.warn "[oboe/loading] Couldn't properly instrument em-http-request (:parse_response_header).  Partial traces may occur."
    end
  end
end
