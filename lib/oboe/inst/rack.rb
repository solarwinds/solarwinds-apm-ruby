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
      @env = env
      header = env['HTTP_X_TRACE']

      result, header = Oboe::API.start_trace('rack', header) do
        env['HTTP_X_TRACE'] = Oboe::Context.toString()
        @app.call(env)
      end
      result
    rescue Exception => e
      header = e.instance_variable_get(:@xtrace)
      raise
    ensure
      env['HTTP_X_TRACE'] = header if header
      result
    end
  end
end

