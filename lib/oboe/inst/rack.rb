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
        report_kvs[:SampleSource]      = Oboe::Config[:sample_source]
        report_kvs['HTTP-Host']        = req.host
        report_kvs['Port']             = req.port
        report_kvs['Proto']            = req.scheme
        report_kvs['Query-String']     = req.query_string unless req.query_string.blank?
        report_kvs[:URL]               = req.path
        report_kvs[:Method]            = req.request_method
        report_kvs['AJAX']             = true if req.xhr?
        report_kvs['ClientIP']         = req.ip
         
        report_kvs['TV-Meta']          = env['HTTP_X-TV-META']          if env.has_key?('HTTP_X-TV-META')
        report_kvs['Forwarded-For']    = env['HTTP_X-FORWARDED-FOR']    if env.has_key?('HTTP_X-FORWARDED-FOR')
        report_kvs['Forwarded-Host']   = env['HTTP_X-FORWARDED-HOST']   if env.has_key?('HTTP_X-FORWARDED-HOST')
        report_kvs['Forwarded-Proto']  = env['HTTP_X-FORWARDED-PROTO']  if env.has_key?('HTTP_X-FORWARDED-PROTO')
        report_kvs['Forwarded-Port']   = env['HTTP_X-FORWARDED-PORT']   if env.has_key?('HTTP_X-FORWARDED-PORT')
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

