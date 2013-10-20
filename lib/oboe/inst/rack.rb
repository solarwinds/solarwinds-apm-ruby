# Copyright (c) 2013 AppNeta, Inc.
# All rights reserved.

module Oboe
  class Rack
    attr_reader :app

    def initialize(app)
      @app = app
    end

    def collect(env)
      report_kvs = {}

      begin
        req = ::Rack::Request.new(env)
        report_kvs[:SampleRate]        = Oboe::Config[:sample_rate]
        report_kvs[:SampleSource]      = Oboe::Config[:sample_source]
        report_kvs['HTTP-Host']        = req.host
        report_kvs['Port']             = req.port
        report_kvs['Proto']            = req.scheme
        report_kvs['Query-String']     = req.query_string unless req.query_string.empty?
        report_kvs[:URL]               = req.path
        report_kvs[:Method]            = req.request_method
        report_kvs['AJAX']             = true if req.xhr?
        report_kvs['ClientIP']         = req.ip

        report_kvs['X-TV-Meta']        = env['HTTP_X_TV_META']          if env.has_key?('HTTP_X_TV_META')

        # Report any request queue'ing headers.  Report as 'Request-Start' or the summed Queue-Time
        report_kvs['Request-Start']    = env['HTTP_X_REQUEST_START']    if env.has_key?('HTTP_X_REQUEST_START')
        report_kvs['Request-Start']    = env['HTTP_X_QUEUE_START']      if env.has_key?('HTTP_X_QUEUE_START')
        report_kvs['Queue-Time']       = env['HTTP_X_QUEUE_TIME']       if env.has_key?('HTTP_X_QUEUE_TIME')

        report_kvs['Forwarded-For']    = env['HTTP_X_FORWARDED_FOR']    if env.has_key?('HTTP_X_FORWARDED_FOR')
        report_kvs['Forwarded-Host']   = env['HTTP_X_FORWARDED_HOST']   if env.has_key?('HTTP_X_FORWARDED_HOST')
        report_kvs['Forwarded-Proto']  = env['HTTP_X_FORWARDED_PROTO']  if env.has_key?('HTTP_X_FORWARDED_PROTO')
        report_kvs['Forwarded-Port']   = env['HTTP_X_FORWARDED_PORT']   if env.has_key?('HTTP_X_FORWARDED_PORT')
      rescue Exception => e
        # Discard any potential exceptions. Debug log and report whatever we can.
        Oboe.logger.debug "[oboe/debug] Rack KV collection error: #{e.inspect}"
      end
      report_kvs
    end

    def call(env)
      report_kvs = {}
      xtrace = env.is_a?(Hash) ? env['HTTP_X_TRACE'] : nil

      result, xtrace = Oboe::API.start_trace('rack', xtrace, report_kvs) do

        status, headers, response = @app.call(env)

        if Oboe.tracing?
          report_kvs = collect(env) 
          Oboe::API.log(nil, 'info', report_kvs.merge!({ :Status => status }))
        end

        [status, headers, response]
      end
    rescue Exception => e
      xtrace = e.instance_variable_get(:@xtrace)
      raise
    ensure
      result[1]['X-Trace'] = xtrace if xtrace
      return result
    end
  end
end

