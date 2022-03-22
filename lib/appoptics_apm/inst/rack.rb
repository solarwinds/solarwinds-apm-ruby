# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'uri'
require 'cgi'

if SolarWindsAPM.loaded
  module SolarWindsAPM
    ##
    # SolarWindsAPM::Rack
    #
    # The SolarWindsAPM::Rack middleware used to sample a subset of incoming
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
        return @app.call(env) if SolarWindsAPM.tracing? && SolarWindsAPM.layer == :rack

        incoming = SolarWindsAPM::Context.isValid
        SolarWindsAPM.transaction_name = nil

        url = env['PATH_INFO']
        options = SolarWindsAPM::XTraceOptions.new(env['HTTP_X_TRACE_OPTIONS'], env['HTTP_X_TRACE_OPTIONS_SIGNATURE'])

        # store incoming information in a thread local variable
        settings = SolarWindsAPM::TransactionSettings.new(url, env, options)

        profile_spans = SolarWindsAPM::Config['profiling'] == :enabled ? 1 : -1

        response =
          propagate_tracecontext(env, settings) do
            sample(env, settings, options, profile_spans) do
              SolarWindsAPM::Profiling.run do
                SolarWindsAPM::TransactionMetrics.metrics(env, settings) do
                  @app.call(env)
                end
              end
            end
          end || [500, {}, nil]
        options.add_response_header(response[1], settings)

        unless incoming
          SolarWindsAPM::Context.clear
          SolarWindsAPM.trace_context = nil
        end
        response
      rescue
        unless incoming
          SolarWindsAPM::Context.clear
          SolarWindsAPM.trace_context = nil
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

          if SolarWindsAPM::Config[:rack][:log_args]
            report_kvs[:'Query-String'] = ::CGI.unescape(req.query_string) unless req.query_string.empty?
          end

          report_kvs[:URL] = SolarWindsAPM::Config[:rack][:log_args] ? ::CGI.unescape(req.fullpath) : ::CGI.unescape(req.path)
          report_kvs[:Backtrace] = SolarWindsAPM::API.backtrace if SolarWindsAPM::Config[:rack][:collect_backtraces]

          # Report any request queue'ing headers.  Report as 'Request-Start' or the summed Queue-Time
          report_kvs[:'Request-Start']     = env['HTTP_X_REQUEST_START']    if env.key?('HTTP_X_REQUEST_START')
          report_kvs[:'Request-Start']     = env['HTTP_X_QUEUE_START']      if env.key?('HTTP_X_QUEUE_START')
          report_kvs[:'Queue-Time']        = env['HTTP_X_QUEUE_TIME']       if env.key?('HTTP_X_QUEUE_TIME')

          report_kvs[:'Forwarded-For']     = env['HTTP_X_FORWARDED_FOR']    if env.key?('HTTP_X_FORWARDED_FOR')
          report_kvs[:'Forwarded-Host']    = env['HTTP_X_FORWARDED_HOST']   if env.key?('HTTP_X_FORWARDED_HOST')
          report_kvs[:'Forwarded-Proto']   = env['HTTP_X_FORWARDED_PROTO']  if env.key?('HTTP_X_FORWARDED_PROTO')
          report_kvs[:'Forwarded-Port']    = env['HTTP_X_FORWARDED_PORT']   if env.key?('HTTP_X_FORWARDED_PORT')

          report_kvs[:'Ruby.SolarWindsAPM.Version'] = SolarWindsAPM::Version::STRING
          report_kvs[:ProcessID]         = Process.pid
          report_kvs[:ThreadID]          = Thread.current.to_s[/0x\w*/]
        rescue StandardError => e
          # Discard any potential exceptions. Debug log and report whatever we can.
          SolarWindsAPM.logger.debug "[appoptics_apm/debug] Rack KV collection error: #{e.inspect}"
        end
        report_kvs
      end

      # this adds x-trace info to the request and return header
      # if it is not a request for an asset (defined in config file as 'dnt')
      def propagate_tracecontext(env, settings)
        return yield unless settings.do_propagate

        # TODO find out why we used to update/add the request HTTP_X_TRACE header
        #  maybe to update the tracing decision for the actual rack call
        #  which may be passed to a different thread

        # TODO add test coverage for this
        if SolarWindsAPM.trace_context&.tracestring
          # creating a dup because we are modifying it when setting/unsetting the sampling bit
          tracestring_dup = SolarWindsAPM.trace_context.tracestring.dup
          if settings.do_sample
            SolarWindsAPM::TraceString.set_sampled(tracestring_dup)
          else
            SolarWindsAPM::TraceString.unset_sampled(tracestring_dup)
          end
          env['HTTP_TRACEPARENT'] = tracestring_dup
          env['HTTP_TRACESTATE'] = SolarWindsAPM::TraceState.add_sw_member(
            SolarWindsAPM.trace_context&.tracestate,
            SolarWindsAPM::TraceString.span_id_flags(tracestring_dup)
          )
        end

        status, headers, response = yield

        # TODO this will be finalized when we have a spec for w3c response headers
        headers ||= {}
        headers['X-Trace'] = SolarWindsAPM::Context.toString if SolarWindsAPM::Context.isValid

        [status, headers, response]
      end

      def sample(env, settings, options, profile_spans)
        if settings.do_sample
          begin
            report_kvs = collect(env)
            settings.add_kvs(report_kvs)
            options&.add_kvs(report_kvs, settings)

            SolarWindsAPM::API.log_start(:rack, report_kvs, env, settings)

            status, headers, response = yield

            SolarWindsAPM::API.log_exit(:rack, { Status: status,
                                                TransactionName: SolarWindsAPM.transaction_name,
                                                ProfileSpans: profile_spans })

            [status, headers, response]
          rescue Exception => e
            # it is ok to rescue Exception here because we are reraising it (we just need a chance to log_end)
            SolarWindsAPM::API.log_exception(:rack, e)
            SolarWindsAPM::API.log_exit(:rack, { Status: status,
                                                TransactionName: SolarWindsAPM.transaction_name,
                                                ProfileSpans: profile_spans
                                              })
            raise
          end
        else
          SolarWindsAPM::API.create_nontracing_context(SolarWindsAPM.trace_context.tracestring)
          yield
        end
      end

    end
  end
else
  module SolarWindsAPM
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
