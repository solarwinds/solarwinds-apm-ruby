# Copyright (c) 2012 by Tracelytics, Inc.
# All rights reserved.

require 'rack'

module Oboe
  class Rack
    attr_reader :app

    def initialize(app)
      @app = app
    end

    def call(env)
      xtrace = env['HTTP_X_TRACE']

      report_kvs = {}
      report_kvs[:SampleRate] = Oboe::Config[:sample_rate]

      response, xtrace = Oboe::API.start_trace('rack', xtrace, report_kvs) do
        @app.call(env)
      end
    rescue Exception => e
      xtrace = e.instance_variable_get(:@xtrace)
      raise
    ensure
      response[1].merge!({'X-Trace' => xtrace}) if xtrace
      return response
    end
  end
end

