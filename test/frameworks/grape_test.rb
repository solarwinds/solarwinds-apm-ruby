unless (RUBY_VERSION =~ /^1.8/) == 0
  require 'minitest_helper'
  require File.expand_path(File.dirname(__FILE__) + '/apps/grape_simple')

  describe Grape do
    before do
      clear_all_traces
    end

    it "should trace a request to a simple grape stack" do
      @app = GrapeSimple

      r = get "/json_endpoint"

      traces = get_all_traces
      traces.count.must_equal 5

      validate_outer_layers(traces, 'rack')

      traces[1]['Layer'].must_equal "grape"
      traces[2]['Layer'].must_equal "grape"
      traces[3]['Label'].must_equal "info"
    end
  end
end
