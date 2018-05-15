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
    # and act accordingly. (to instrument or not)
    #
    class Rack
      attr_reader :app

      def initialize(app)
        @app = app
      end

      def collect(req, env)
        report_kvs = {}

        begin
          report_kvs[:'HTTP-Host']        = req.host
          report_kvs[:Port]             = req.port
          report_kvs[:Proto]            = req.scheme
          report_kvs[:Method]            = req.request_method
          report_kvs[:AJAX]             = true if req.xhr?
          report_kvs[:ClientIP]         = req.ip

          if AppOpticsAPM::Config[:rack][:log_args]
            report_kvs[:'Query-String']     = ::CGI.unescape(req.query_string) unless req.query_string.empty?
          end

          # Report any request queue'ing headers.  Report as 'Request-Start' or the summed Queue-Time
          report_kvs[:'Request-Start']     = env['HTTP_X_REQUEST_START']    if env.key?('HTTP_X_REQUEST_START')
          report_kvs[:'Request-Start']     = env['HTTP_X_QUEUE_START']      if env.key?('HTTP_X_QUEUE_START')
          report_kvs[:'Queue-Time']        = env['HTTP_X_QUEUE_TIME']       if env.key?('HTTP_X_QUEUE_TIME')

          report_kvs[:'Forwarded-For']     = env['HTTP_X_FORWARDED_FOR']    if env.key?('HTTP_X_FORWARDED_FOR')
          report_kvs[:'Forwarded-Host']    = env['HTTP_X_FORWARDED_HOST']   if env.key?('HTTP_X_FORWARDED_HOST')
          report_kvs[:'Forwarded-Proto']   = env['HTTP_X_FORWARDED_PROTO']  if env.key?('HTTP_X_FORWARDED_PROTO')
          report_kvs[:'Forwarded-Port']    = env['HTTP_X_FORWARDED_PORT']   if env.key?('HTTP_X_FORWARDED_PORT')

          report_kvs[:'Ruby.AppOpticsAPM.Version'] = ::AppOpticsAPM::Version::STRING
          report_kvs[:ProcessID]         = Process.pid
          report_kvs[:ThreadID]          = Thread.current.to_s[/0x\w*/]
        rescue StandardError => e
          # Discard any potential exceptions. Debug log and report whatever we can.
          AppOpticsAPM.logger.debug "[appoptics_apm/debug] Rack KV collection error: #{e.inspect}"
        end
        report_kvs
      end

      def call(env)
        AppOpticsAPM.transaction_name = nil
        confirmed_transaction_name = nil
        start = Time.now
        status = 500
        req = ::Rack::Request.new(env)
        req_url = req.url   # saving it here because rails3.2 overrides it when there is a 500 error

        # In the case of nested Ruby apps such as Grape inside of Rails
        # or Grape inside of Grape, each app has it's own instance
        # of rack middleware.  We avoid tracing rack more than once and
        # instead start instrumenting from the first rack pass.
        # TODO extend this for metrics
        if AppOpticsAPM.tracing? && AppOpticsAPM.layer == :rack
          AppOpticsAPM.logger.debug "[appoptics_apm/rack] Rack skipped!"
          return @app.call(env)
        end

        begin
          report_kvs = {}

          report_kvs[:URL] = AppOpticsAPM::Config[:rack][:log_args] ? ::CGI.unescape(req.fullpath) : ::CGI.unescape(req.path)

          # Check for and validate X-Trace request header to pick up tracing context
          xtrace = env.is_a?(Hash) ? env['HTTP_X_TRACE'] : nil
          xtrace_header = AppOpticsAPM::XTrace.valid?(xtrace) ? xtrace : nil

          # Under JRuby, JAppOpticsAPM may have already started a trace.  Make note of this
          # if so and don't clear context on log_end (see appoptics_apm/api/logging.rb)
          AppOpticsAPM.has_incoming_context = AppOpticsAPM.tracing?
          AppOpticsAPM.has_xtrace_header = xtrace_header
          AppOpticsAPM.is_continued_trace = AppOpticsAPM.has_incoming_context || AppOpticsAPM.has_xtrace_header

          xtrace = AppOpticsAPM::API.log_start(:rack, xtrace_header, report_kvs) unless ::AppOpticsAPM::Util.static_asset?(env['PATH_INFO'])
          # We only trace a subset of requests based off of sample rate so if
          # AppOpticsAPM::API.log_start really did start a trace, we act accordingly here.
          if AppOpticsAPM.tracing?
            begin
              report_kvs = collect(req, env)

              # We log an info event with the HTTP KVs found in AppOpticsAPM::Rack.collect
              # This is done here so in the case of stacks that try/catch/abort
              # (looking at you Grape) we're sure the KVs get reported now as
              # this code may not be returned to later.
              AppOpticsAPM::API.log_info(:rack, report_kvs)
              status, headers, response = @app.call(env)
              confirmed_transaction_name = send_metrics(env, req, req_url, start, status)
              xtrace = AppOpticsAPM::API.log_end(:rack, :Status => status, :TransactionName => confirmed_transaction_name)
            rescue Exception => e
              # it is ok to rescue Exception here because we are reraising it (we just need a chance to log_end)
              AppOpticsAPM::API.log_exception(:rack, e)
              confirmed_transaction_name ||= send_metrics(env, req, req_url, start, status)
              xtrace = AppOpticsAPM::API.log_end(:rack, :Status => status, :TransactionName => confirmed_transaction_name)
              raise
            end
          else
            status, headers, response = @app.call(env)
          end

          [status, headers, response]
        ensure # this ensure block is dangerous because it messes with recursion
          if headers && AppOpticsAPM::XTrace.valid?(xtrace)
            headers['X-Trace'] = xtrace if headers.is_a?(Hash) unless defined?(JRUBY_VERSION) && AppOpticsAPM.is_continued_trace?
          end
          send_metrics(env, req, req_url, start, status) unless confirmed_transaction_name
        end
      end

      def self.noop?
        false
      end

      private

      def send_metrics(env, req, req_url, start, status)
        unless ::AppOpticsAPM::Util.static_asset?(env['PATH_INFO'])
          domain = nil
          if AppOpticsAPM::Config['transaction_name']['prepend_domain']
            domain = [80, 443].include?(req.port) ? req.host : "#{req.host}:#{req.port}"
          end
          status = status.to_i
          error = status.between?(500,599) ? 1 : 0
          duration =(1000 * 1000 * (Time.now - start)).round(0)
          AppOpticsAPM::Span.createHttpSpan(transaction_name(env), req_url, domain, duration, status, req.request_method, error) || ''
        end
      end

      def transaction_name(env)
        if AppOpticsAPM::transaction_name
          AppOpticsAPM::transaction_name
        elsif env['appoptics_apm.controller'] || env['appoptics_apm.action']
          [env['appoptics_apm.controller'], env['appoptics_apm.action']].join('.')
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
