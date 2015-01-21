# Copyright (c) 2013 AppNeta, Inc.
# All rights reserved.

require 'uri'

module Oboe
  class Rack
    attr_reader :app

    def initialize(app)
      @app = app
    end

    def collect(req, env)
      report_kvs = {}

      begin
        report_kvs['HTTP-Host']        = req.host
        report_kvs['Port']             = req.port
        report_kvs['Proto']            = req.scheme
        report_kvs['Query-String']     = URI.unescape(req.query_string) unless req.query_string.empty?
        report_kvs[:URL]               = URI.unescape(req.path)
        report_kvs[:Method]            = req.request_method
        report_kvs['AJAX']             = true if req.xhr?
        report_kvs['ClientIP']         = req.ip

        report_kvs['X-TV-Meta']         = env['HTTP_X_TV_META']          if env.key?('HTTP_X_TV_META')

        # Report any request queue'ing headers.  Report as 'Request-Start' or the summed Queue-Time
        report_kvs['Request-Start']     = env['HTTP_X_REQUEST_START']    if env.key?('HTTP_X_REQUEST_START')
        report_kvs['Request-Start']     = env['HTTP_X_QUEUE_START']      if env.key?('HTTP_X_QUEUE_START')
        report_kvs['Queue-Time']        = env['HTTP_X_QUEUE_TIME']       if env.key?('HTTP_X_QUEUE_TIME')

        report_kvs['Forwarded-For']     = env['HTTP_X_FORWARDED_FOR']    if env.key?('HTTP_X_FORWARDED_FOR')
        report_kvs['Forwarded-Host']    = env['HTTP_X_FORWARDED_HOST']   if env.key?('HTTP_X_FORWARDED_HOST')
        report_kvs['Forwarded-Proto']   = env['HTTP_X_FORWARDED_PROTO']  if env.key?('HTTP_X_FORWARDED_PROTO')
        report_kvs['Forwarded-Port']    = env['HTTP_X_FORWARDED_PORT']   if env.key?('HTTP_X_FORWARDED_PORT')

        report_kvs['Ruby.Oboe.Version'] = ::Oboe::Version::STRING
        report_kvs['ProcessID']         = Process.pid
        report_kvs['ThreadID']          = Thread.current.to_s[/0x\w*/]
      rescue StandardError => e
        # Discard any potential exceptions. Debug log and report whatever we can.
        Oboe.logger.debug "[oboe/debug] Rack KV collection error: #{e.inspect}"
      end
      report_kvs
    end

    def call(env)
      req = ::Rack::Request.new(env)

      report_kvs = {}
      report_kvs[:URL] = URI.unescape(req.path)

      # Under JRuby, JOboe may have already started a trace.  Make note of this
      # if so and don't clear context on log_end (see oboe/api/logging.rb)
      Oboe.has_incoming_context = Oboe.tracing?

      # Check for and validate X-Trace request header to pick up tracing context
      xtrace = env.is_a?(Hash) ? env['HTTP_X_TRACE'] : nil
      xtrace_header = xtrace if xtrace && Oboe::XTrace.valid?(xtrace)
      Oboe.has_xtrace_header = xtrace_header

      Oboe.is_continued_trace = Oboe.has_incoming_context or Oboe.has_xtrace_header

      # The actual block of work to instrument
      result, xtrace = Oboe::API.start_trace('rack', xtrace_header, report_kvs) do
        status, headers, response = @app.call(env)

        if Oboe.tracing?
          report_kvs = collect(req, env)
          Oboe::API.log(nil, 'info', report_kvs.merge!(:Status => status))
        end

        [status, headers, response]
      end
    rescue Exception => e
      xtrace = e.instance_variable_get(:@xtrace)
      raise
    ensure
      if result && Oboe::XTrace.valid?(xtrace)
        unless defined?(JRUBY_VERSION) && Oboe.is_continued_trace?
          result[1]['X-Trace'] = xtrace if result[1].is_a?(Hash)
        end
      end
      return result
    end
  end
end

