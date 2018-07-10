# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

module AppOpticsAPM
  module Inst
    module EventMachine
      module HttpConnection
        def setup_request_with_appoptics(*args, &block)
          context = AppOpticsAPM::Context.toString
          blacklisted = AppOpticsAPM::API.blacklisted?(@uri)

          if AppOpticsAPM.tracing?
            report_kvs = {}

            begin
              report_kvs[:IsService] = 1
              report_kvs[:RemoteURL] = @uri
              report_kvs[:HTTPMethod] = args[0]
              report_kvs[:Blacklisted] = true if blacklisted

              if AppOpticsAPM::Config[:em_http_request][:collect_backtraces]
                report_kvs[:Backtrace] = AppOpticsAPM::API.backtrace
              end
            rescue => e
              AppOpticsAPM.logger.debug "[appoptics_apm/debug] em-http-request KV error: #{e.inspect}"
            end

            ::AppOpticsAPM::API.log_entry('em-http-request', report_kvs)
          end
          client = setup_request_without_appoptics(*args, &block)
          client.req.headers['X-Trace'] = context unless blacklisted
          client
        end
      end

      module HttpClient
        def parse_response_header_with_appoptics(*args, &block)
          report_kvs = {}
          xtrace = nil
          blacklisted = AppOpticsAPM::API.blacklisted?(@uri)

          begin
            report_kvs[:HTTPStatus] = args[2]
            report_kvs[:Async] = 1
          rescue => e
            AppOpticsAPM.logger.debug "[appoptics_apm/debug] em-http-request KV error: #{e.inspect}"
          end

          parse_response_header_without_appoptics(*args, &block)

          unless blacklisted
            headers = args[0]
            context = AppOpticsAPM::Context.toString
            task_id = AppOpticsAPM::XTrace.task_id(context)

            if headers.is_a?(Hash) && headers.key?('X-Trace')
              xtrace = headers['X-Trace']
            end

            if AppOpticsAPM::XTrace.valid?(xtrace) && AppOpticsAPM.tracing?

              # Assure that we received back a valid X-Trace with the same task_id
              if task_id == AppOpticsAPM::XTrace.task_id(xtrace)
                AppOpticsAPM::Context.fromString(xtrace)
              else
                AppOpticsAPM.logger.debug "[appoptics_apm/em-http] Mismatched returned X-Trace ID : #{xtrace}"
              end
            end

          end
        ensure
          ::AppOpticsAPM::API.log_exit(:'em-http-request', report_kvs)
        end
      end
    end
  end
end

if defined?(::EventMachine::HttpConnection) && defined?(::EventMachine::HttpClient) && AppOpticsAPM::Config[:em_http_request][:enabled]
  AppOpticsAPM.logger.info '[appoptics_apm/loading] Instrumenting em-http-request' if AppOpticsAPM::Config[:verbose]

  class ::EventMachine::HttpConnection
    include AppOpticsAPM::Inst::EventMachine::HttpConnection

    if method_defined?(:setup_request)
      class_eval 'alias :setup_request_without_appoptics :setup_request'
      class_eval 'alias :setup_request :setup_request_with_appoptics'
    else
      AppOpticsAPM.logger.warn '[appoptics_apm/loading] Couldn\'t properly instrument em-http-request (:setup_request).  Partial traces may occur.'
    end
  end

  class ::EventMachine::HttpClient
    include AppOpticsAPM::Inst::EventMachine::HttpClient

    if method_defined?(:parse_response_header)
      class_eval 'alias :parse_response_header_without_appoptics :parse_response_header'
      class_eval 'alias :parse_response_header :parse_response_header_with_appoptics'
    else
      AppOpticsAPM.logger.warn '[appoptics_apm/loading] Couldn\'t properly instrument em-http-request (:parse_response_header).  Partial traces may occur.'
    end
  end
end
