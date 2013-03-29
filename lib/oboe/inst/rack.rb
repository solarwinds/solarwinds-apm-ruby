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
      xtrace = env['HTTP_X_TRACE']

      begin
        req = ::Rack::Request.new(env)
        report_kvs[:SampleRate]      = Oboe::Config[:sample_rate]
        report_kvs['HTTP-Host']      = req.host
        report_kvs['HTTP-Port']      = req.port
        report_kvs['Query-String']   = req.query_string unless req.query_string.blank?
        report_kvs[:URL]             = req.path
        report_kvs[:Method]          = req.request_method
        report_kvs['AJAX']           = true if req.xhr?
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

