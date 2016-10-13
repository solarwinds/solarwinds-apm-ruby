# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require "minitest_helper"

if RUBY_VERSION >= '1.9.3' and defined?(::Padrino)
  require File.expand_path(File.dirname(__FILE__) + '/apps/padrino_simple')

  describe Padrino do
    before do
      clear_all_traces
    end

    it "should trace a request to a simple padrino stack" do
      @app = SimpleDemo

      r = get "/render"

      traces = get_all_traces

      traces.count.must_equal 9
      valid_edges?(traces).must_equal true
      validate_outer_layers(traces, 'rack')

      traces[2]['Layer'].must_equal "padrino"
      traces[7]['Controller'].must_equal "SimpleDemo"
      traces[8]['Label'].must_equal "exit"

      # Validate the existence of the response header
      r.headers.key?('X-Trace').must_equal true
      r.headers['X-Trace'].must_equal traces[8]['X-Trace']
    end
  end
end
