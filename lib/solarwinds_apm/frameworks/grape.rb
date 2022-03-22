# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.
#
class GrapeError < StandardError; end

module SolarWindsAPM
  module Grape
    module API
      def self.extended(klass)
        SolarWindsAPM::Util.class_method_alias(klass, :inherited, ::Grape::API)
      end

      def inherited_with_sw_apm(subclass)
        inherited_without_sw_apm(subclass)

        subclass.use SolarWindsAPM::Rack
      end
    end

    module Endpoint
      def self.included(klass)
        SolarWindsAPM::Util.method_alias(klass, :run, ::Grape::Endpoint)
      end

      def run_with_sw_apm(*args)
        # Report Controller/Action and Transaction as best possible
        report_kvs = {}

        report_kvs[:Controller] = options[:for].to_s
        report_kvs[:Action] =
          if route&.pattern
            route.options ? "#{route.options[:method]}#{route.pattern.origin}" : route.pattern.origin
          else
            args.empty? ? env['PATH_INFO'] : args[0]['PATH_INFO']
          end
        report_kvs[:Backtrace] = SolarWindsAPM::API.backtrace if SolarWindsAPM::Config[:grape][:collect_backtraces]

        env['solarwinds_apm.controller'] = report_kvs[:Controller]
        env['solarwinds_apm.action'] = report_kvs[:Action]

        SolarWindsAPM::API.log_entry('grape', report_kvs)

        run_without_sw_apm(*args)
      ensure
        SolarWindsAPM::API.log_exit('grape')
      end
    end

    module Middleware
      module Error
        def self.included(klass)
          SolarWindsAPM::Util.method_alias(klass, :error_response, ::Grape::Middleware::Error)
        end

        def error_response_with_sw_apm(error = {})
          response = error_response_without_sw_apm(error)
          status, headers, _body = response.finish

          tracestring = SolarWindsAPM::Context.toString

          if SolarWindsAPM.tracing?
            # Since Grape uses throw/catch and not Exceptions, we have to create an exception here
            exception = GrapeError.new(error[:message] ? error[:message] : "No message given.")
            exception.set_backtrace(SolarWindsAPM::API.backtrace)

            SolarWindsAPM::API.log_exception('rack', exception)

            # Since calls to error() are handled similar to abort in Grape.  We
            # manually log the rack exit here since the original code won't
            # be returned to
            tracestring = SolarWindsAPM::API.log_end('rack', :Status => status)
          end

          if headers && SolarWindsAPM::TraceString.valid?(tracestring)
            unless defined?(JRUBY_VERSION) && SolarWindsAPM.is_continued_trace?
              # this will change later, w3c outgoing headers have not been standardized yet
              headers['X-Trace'] = tracestring if headers.is_a?(Hash)
            end
          end

          response
        end
      end
    end
  end
end

if SolarWindsAPM::Config[:grape][:enabled] && defined?(Grape)
  require 'solarwinds_apm/inst/rack'

  SolarWindsAPM.logger.info "[solarwinds_apm/loading] Instrumenting Grape" if SolarWindsAPM::Config[:verbose]

  SolarWindsAPM::Inst.load_instrumentation

  SolarWindsAPM::Util.send_extend(Grape::API, SolarWindsAPM::Grape::API)
  SolarWindsAPM::Util.send_include(Grape::Endpoint, SolarWindsAPM::Grape::Endpoint)
  SolarWindsAPM::Util.send_include(Grape::Middleware::Error, SolarWindsAPM::Grape::Middleware::Error)
end
