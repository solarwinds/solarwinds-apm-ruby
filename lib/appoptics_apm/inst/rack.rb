# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'uri'
require 'cgi'

if AppOpticsAPM.loaded
  module AppOpticsAPM
    ##
    # AppOpticsAPM::Rack
    #
    # The AppOpticsAPM::Rack middleware used to sample a subset of incoming
    # requests for instrumentation and reporting.  Tracing context can
    # be received here (via the X-Trace HTTP header) or initiated here
    # based on configured tracing mode.
    #
    # After the rack layer passes on to the following layers (Rails, Sinatra,
    # Padrino, Grape), then the instrumentation downstream will
    # automatically detect whether this is a sampled request or not
    # and act accordingly.
    #
    class Rack
      attr_reader :app

      def initialize(app)
        @app = app
      end

      def call(env)

        # In the case of nested Ruby apps such as Grape inside of Rails
        # or Grape inside of Grape, each app has it's own instance
        # of rack middleware. We want to avoid tracing rack more than once
        return @app.call(env) if AppOpticsAPM.tracing? && AppOpticsAPM.layer == :rack

        incoming = AppOpticsAPM::Context.isValid
        AppOpticsAPM.transaction_name = nil

        url = env['PATH_INFO']
        options = AppOpticsAPM::XTraceOptions.new(env['HTTP_X_TRACE_OPTIONS'], env['HTTP_X_TRACE_OPTIONS_SIGNATURE'])

        # store incoming information in a thread local variable
        AppOpticsAPM.trace_context = TraceContext.new(env['HTTP_TRACEPARENT'], env['HTTP_TRACESTATE'])
        xtrace = AppOpticsAPM.trace_context.xtrace
        settings = AppOpticsAPM::TransactionSettings.new(url, xtrace, options)
        profile_spans = AppOpticsAPM::Config['profiling'] == :enabled ? 1 : -1

        response =
          propagate_xtrace(env, settings, xtrace) do
            sample(env, settings, options, profile_spans) do
              AppOpticsAPM::Profiling.run do
                AppOpticsAPM::TransactionMetrics.metrics(env, settings) do
                  @app.call(env)
                end
              end
            end
          end || [500, {}, nil]
        options.add_response_header(response[1], settings)

        unless incoming
          AppOpticsAPM::Context.clear
          AppOpticsAPM.trace_context = nil
        end
        response
      rescue
        unless incoming
          AppOpticsAPM::Context.clear
          AppOpticsAPM.trace_context = nil
        end
        raise
        # can't use ensure for Context.clearing, because the Grape middleware
        # needs the context in case of an error, it is somewhat convoluted ...
      end

      def self.noop?
        false
      end

      private

      def collect(env)
        req = ::Rack::Request.new(env)
        report_kvs = {}

        begin
          report_kvs[:'HTTP-Host']      = req.host
          report_kvs[:Port]             = req.port
          report_kvs[:Proto]            = req.scheme
          report_kvs[:Method]           = req.request_method
          report_kvs[:AJAX]             = true if req.xhr?
          report_kvs[:ClientIP]         = req.ip

          if AppOpticsAPM::Config[:rack][:log_args]
            report_kvs[:'Query-String'] = ::CGI.unescape(req.query_string) unless req.query_string.empty?
          end

          report_kvs[:URL] = AppOpticsAPM::Config[:rack][:log_args] ? ::CGI.unescape(req.fullpath) : ::CGI.unescape(req.path)
          report_kvs[:Backtrace] = AppOpticsAPM::API.backtrace if AppOpticsAPM::Config[:rack][:collect_backtraces]

          # Report any request queue'ing headers.  Report as 'Request-Start' or the summed Queue-Time
          report_kvs[:'Request-Start']     = env['HTTP_X_REQUEST_START']    if env.key?('HTTP_X_REQUEST_START')
          report_kvs[:'Request-Start']     = env['HTTP_X_QUEUE_START']      if env.key?('HTTP_X_QUEUE_START')
          report_kvs[:'Queue-Time']        = env['HTTP_X_QUEUE_TIME']       if env.key?('HTTP_X_QUEUE_TIME')

          report_kvs[:'Forwarded-For']     = env['HTTP_X_FORWARDED_FOR']    if env.key?('HTTP_X_FORWARDED_FOR')
          report_kvs[:'Forwarded-Host']    = env['HTTP_X_FORWARDED_HOST']   if env.key?('HTTP_X_FORWARDED_HOST')
          report_kvs[:'Forwarded-Proto']   = env['HTTP_X_FORWARDED_PROTO']  if env.key?('HTTP_X_FORWARDED_PROTO')
          report_kvs[:'Forwarded-Port']    = env['HTTP_X_FORWARDED_PORT']   if env.key?('HTTP_X_FORWARDED_PORT')

          report_kvs[:'Ruby.AppOptics.Version'] = AppOpticsAPM::Version::STRING
          report_kvs[:ProcessID]         = Process.pid
          report_kvs[:ThreadID]          = Thread.current.to_s[/0x\w*/]
        rescue StandardError => e
          # Discard any potential exceptions. Debug log and report whatever we can.
          AppOpticsAPM.logger.debug "[appoptics_apm/debug] Rack KV collection error: #{e.inspect}"
        end
        report_kvs
      end

      def propagate_xtrace(env, settings, xtrace)
        return yield unless settings.do_propagate

        if xtrace
          xtrace_local = xtrace.dup
          AppOpticsAPM::XTrace.unset_sampled(xtrace_local) unless settings.do_sample
          env['HTTP_TRACEPARENT'] = AppOpticsAPM::TraceContext.ao_to_w3c_trace(xtrace_local)
        end

        status, headers, response = yield

        headers ||= {}
        headers['X-Trace'] = AppOpticsAPM::Context.toString if AppOpticsAPM::Context.isValid
        headers['X-Trace'] ||= xtrace if xtrace
        headers['X-Trace'] && AppOpticsAPM::XTrace.unset_sampled(headers['X-Trace']) unless settings.do_sample

        [status, headers, response]
      end

      def sample(env, settings, options, profile_spans)
        xtrace = AppOpticsAPM.trace_context.parent_xtrace
        if settings.do_sample
          begin
            report_kvs = collect(env)
            settings.add_kvs(report_kvs)
            options&.add_kvs(report_kvs, settings)
            AppOpticsAPM.trace_context&.add_kvs(report_kvs)
            AppOpticsAPM::API.log_start(:rack, xtrace, report_kvs, settings)

            status, headers, response = yield

            AppOpticsAPM::API.log_exit(:rack, { Status: status,
                                                TransactionName: AppOpticsAPM.transaction_name,
                                                ProfileSpans: profile_spans})

            [status, headers, response]
          rescue Exception => e
            # it is ok to rescue Exception here because we are reraising it (we just need a chance to log_end)
            AppOpticsAPM::API.log_exception(:rack, e)
            AppOpticsAPM::API.log_exit(:rack, { Status: status,
                                                TransactionName: AppOpticsAPM.transaction_name,
                                                ProfileSpans: profile_spans
                                              })
            raise
          end
        else
          AppOpticsAPM::API.create_nontracing_context(xtrace)
          yield
        end
      end

    end
  end
else
  module AppOpticsAPM
    class Rack
      attr_reader :app

      def initialize(app)
        @app = app
      end

      def call(env)
        @app.call(env)
      end

      def self.noop?
        true
      end
    end
  end
end
