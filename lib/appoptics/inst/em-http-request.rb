# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

module AppOptics
  module Inst
    module EventMachine
      module HttpConnection
        def setup_request_with_appoptics(*args, &block)
          context = AppOptics::Context.toString
          blacklisted = AppOptics::API.blacklisted?(@uri)

          if AppOptics.tracing?
            report_kvs = {}

            begin
              report_kvs[:IsService] = 1
              report_kvs[:RemoteURL] = @uri
              report_kvs[:HTTPMethod] = args[0]
              report_kvs[:Blacklisted] = true if blacklisted

              if AppOptics::Config[:em_http_request][:collect_backtraces]
                report_kvs[:Backtrace] = AppOptics::API.backtrace
              end
            rescue => e
              AppOptics.logger.debug "[appoptics/debug] em-http-request KV error: #{e.inspect}"
            end

            ::AppOptics::API.log_entry('em-http-request', report_kvs)
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
          blacklisted = AppOptics::API.blacklisted?(@uri)

          begin
            report_kvs[:HTTPStatus] = args[2]
            report_kvs[:Async] = 1
          rescue => e
            AppOptics.logger.debug "[appoptics/debug] em-http-request KV error: #{e.inspect}"
          end

          parse_response_header_without_appoptics(*args, &block)

          unless blacklisted
            headers = args[0]
            context = AppOptics::Context.toString
            task_id = AppOptics::XTrace.task_id(context)

            if headers.is_a?(Hash) && headers.key?('X-Trace')
              xtrace = headers['X-Trace']
            end

            if AppOptics::XTrace.valid?(xtrace) && AppOptics.tracing?

              # Assure that we received back a valid X-Trace with the same task_id
              if task_id == AppOptics::XTrace.task_id(xtrace)
                AppOptics::Context.fromString(xtrace)
              else
                AppOptics.logger.debug "Mismatched returned X-Trace ID : #{xtrace}"
              end
            end

          end
        ensure
          ::AppOptics::API.log_exit(:'em-http-request', report_kvs)
        end
      end
    end
  end
end

if RUBY_VERSION >= '1.9'
  if defined?(::EventMachine::HttpConnection) && defined?(::EventMachine::HttpClient) && AppOptics::Config[:em_http_request][:enabled]
    AppOptics.logger.info '[appoptics/loading] Instrumenting em-http-request' if AppOptics::Config[:verbose]

    class ::EventMachine::HttpConnection
      include AppOptics::Inst::EventMachine::HttpConnection

      if method_defined?(:setup_request)
        class_eval 'alias :setup_request_without_appoptics :setup_request'
        class_eval 'alias :setup_request :setup_request_with_appoptics'
      else
        AppOptics.logger.warn '[appoptics/loading] Couldn\'t properly instrument em-http-request (:setup_request).  Partial traces may occur.'
      end
    end

    class ::EventMachine::HttpClient
      include AppOptics::Inst::EventMachine::HttpClient

      if method_defined?(:parse_response_header)
        class_eval 'alias :parse_response_header_without_appoptics :parse_response_header'
        class_eval 'alias :parse_response_header :parse_response_header_with_appoptics'
      else
        AppOptics.logger.warn '[appoptics/loading] Couldn\'t properly instrument em-http-request (:parse_response_header).  Partial traces may occur.'
      end
    end
  end
end
