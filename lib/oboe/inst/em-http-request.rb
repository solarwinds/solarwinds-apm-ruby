module Oboe
  module Inst
    module EventMachine
      module HttpConnection
        def setup_request_with_oboe(*args, &block)
          report_kvs = {}

          report_kvs['IsService'] = 1
          report_kvs['RemoteURL'] = @uri
          report_kvs['HTTPMethod'] = args[0] if args.is_a?(Array) and args.length
          report_kvs['Blacklisted'] = true if Oboe::API.blacklisted?(@uri)

          report_kvs[:Backtrace] = Oboe::API.backtrace if Oboe::Config[:em_http_request][:collect_backtraces]

          ::Oboe::API.log_entry('em-http-request', report_kvs)
          client = setup_request_without_oboe(*args, &block)
          client.req.headers["X-Trace"] = Oboe::Context.toString()
          client
        end
      end

      module HttpClient
        def parse_response_header_with_oboe(*args, &block)
          report_kvs = {}
          report_kvs[:HTTPStatus] = args[2] if args.is_a?(Array) and args.length >= 3
          report_kvs[:Async] = 1

          parse_response_header_without_oboe(*args, &block)
          ::Oboe::API.log_exit('em-http-request', report_kvs)
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
