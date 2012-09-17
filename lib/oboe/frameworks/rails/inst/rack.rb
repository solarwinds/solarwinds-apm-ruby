# Copyright (c) 2012 by Tracelytics, Inc.
# All rights reserved.

module Oboe
  class Middleware
    def initialize(app)
      @app = app
    end

    def call(env)
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
    end
  end
end

if false and defined?(Rails.configuration.middleware)
  puts "[oboe/loading] Instrumenting rack" if Oboe::Config[:verbose]
  Rails.configuration.middleware.insert 0, Oboe::Middleware
end
