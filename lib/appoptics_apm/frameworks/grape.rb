# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.
#
class GrapeError < StandardError; end

module AppOpticsAPM
  module Grape
    module API
      def self.extended(klass)
        ::AppOpticsAPM::Util.class_method_alias(klass, :inherited, ::Grape::API)
      end

      def inherited_with_appoptics(subclass)
        inherited_without_appoptics(subclass)

        subclass.use ::AppOpticsAPM::Rack
      end
    end

    module Endpoint
      def self.included(klass)
        ::AppOpticsAPM::Util.method_alias(klass, :run, ::Grape::Endpoint)
      end

      def run_with_appoptics(*args)
        # Report Controller/Action and Transaction as best possible
        report_kvs = {}

        report_kvs[:Controller] = options[:for].name
        if route && route.pattern
          report_kvs[:Action] = route.options ? "#{route.options[:method]}#{route.pattern.origin}" : route.pattern.origin
          # report_kvs[:Action] = route.pattern.origin
        else
          report_kvs[:Action] = args.empty? ? env['PATH_INFO'] : args[0]['PATH_INFO']
        end

        env['appoptics_apm.controller'] = report_kvs[:Controller]
        env['appoptics_apm.action']     = report_kvs[:Action]

        ::AppOpticsAPM::API.log_entry('grape', report_kvs)

        run_without_appoptics(*args)
      ensure
        ::AppOpticsAPM::API.log_exit('grape')
      end
    end

    module Middleware
      module Error
        def self.included(klass)
          ::AppOpticsAPM::Util.method_alias(klass, :error_response, ::Grape::Middleware::Error)
        end

        def error_response_with_appoptics(error = {})
          status, headers, body = error_response_without_appoptics(error)

          xtrace = AppOpticsAPM::Context.toString

          if AppOpticsAPM.tracing?

            # Since Grape uses throw/catch and not Exceptions, we have to create an exception here
            exception = GrapeError.new(error[:message] ? error[:message] : "No message given.")
            exception.set_backtrace(::AppOpticsAPM::API.backtrace) if AppOpticsAPM::Config[:grape][:collect_backtraces]

            ::AppOpticsAPM::API.log_exception('rack', exception )

            # Since calls to error() are handled similar to abort in Grape.  We
            # manually log the rack exit here since the original code won't
            # be returned to
            xtrace = AppOpticsAPM::API.log_end('rack', :Status => status)
          end

          if headers && AppOpticsAPM::XTrace.valid?(xtrace)
            unless defined?(JRUBY_VERSION) && AppOpticsAPM.is_continued_trace?
              headers['X-Trace'] = xtrace if headers.is_a?(Hash)
            end
          end

          [status, headers, body]
        end
      end
    end
  end
end

if AppOpticsAPM::Config[:grape][:enabled] && defined?(::Grape)
  require 'appoptics_apm/inst/rack'

  AppOpticsAPM.logger.info "[appoptics_apm/loading] Instrumenting Grape" if AppOpticsAPM::Config[:verbose]

  AppOpticsAPM::Inst.load_instrumentation

  ::AppOpticsAPM::Util.send_extend(::Grape::API,               ::AppOpticsAPM::Grape::API)
  ::AppOpticsAPM::Util.send_include(::Grape::Endpoint,          ::AppOpticsAPM::Grape::Endpoint)
  ::AppOpticsAPM::Util.send_include(::Grape::Middleware::Error, ::AppOpticsAPM::Grape::Middleware::Error)
end
