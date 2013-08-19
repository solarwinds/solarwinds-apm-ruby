# Copyright (c) 2012 by Tracelytics, Inc.
# All rights reserved.

module Oboe
  class Rack
    attr_reader :app

    def initialize(app)
      @app = app
    end

    def call(env)
      report_kvs = {}
      xtrace = nil

      begin
        xtrace = env['HTTP_X_TRACE'] if env.is_a?(Hash)
        
        req = ::Rack::Request.new(env)
        report_kvs[:SampleRate]        = Oboe::Config[:sample_rate]
        report_kvs['HTTP-Host']        = req.host
        report_kvs['Port']             = req.port
        report_kvs['Query-String']     = req.query_string unless req.query_string.blank?
        report_kvs[:URL]               = req.path
        report_kvs[:Method]            = req.request_method
        report_kvs['AJAX']             = true if req.xhr?
         
        report_kvs['TV-Meta']          = env['X-TV-Meta']          if env.has_key?('X-TV-Meta')
        report_kvs['ClientIP']         = env['REMOTE_ADDR']        if env.has_key?('REMOTE_ADDR')
        report_kvs['Forwarded-For']    = env['X-Forwarded-For']    if env.has_key?('X-Forwarded-For')
        report_kvs['Forwarded-Host']   = env['X-Forwarded-Host']   if env.has_key?('X-Forwarded-Host')
        report_kvs['Forwarded-Proto']  = env['X-Forwarded-Proto']  if env.has_key?('X-Forwarded-Proto')
        report_kvs['Forwarded-Port']   = env['X-Forwarded-Port']   if env.has_key?('X-Forwarded-Port')
      rescue
        # Discard any potential exceptions. Report whatever we can.
      end

      result, xtrace = Oboe::API.start_trace('rack', xtrace, report_kvs) do

        status, headers, response = @app.call(env)
        Oboe::API.log(nil, 'info', { :Status => status })

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

