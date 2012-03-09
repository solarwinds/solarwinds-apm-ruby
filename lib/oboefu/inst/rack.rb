# Copyright (c) 2012 by Tracelytics, Inc.
# All rights reserved.

module Oboe
  class Middleware
    def initialize(app)
      @app = app
    end

    def call(env)
      header = env['HTTP_X_TRACE']

      result, header = Oboe::Inst.trace_start_layer_block('rack', header) do |exitEvent|
        env['HTTP_X_TRACE'] = Oboe::Context.toString()
        @app.call(env)
      end

      env['HTTP_X_TRACE'] = header if header
      result
    end
  end
end

if false and defined?(Rails.configuration.middleware)
  puts "[oboe_fu/loading] Instrumenting rack"
  Rails.configuration.middleware.insert 0, Oboe::Middleware
end
