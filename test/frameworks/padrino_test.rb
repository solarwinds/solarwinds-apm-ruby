unless (RUBY_VERSION =~ /^1.8/) == 0
  require "minitest_helper"
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

      validate_outer_layers(traces, 'rack')

      traces[1]['Layer'].must_equal "padrino"
      traces[6]['Controller'].must_equal "SimpleDemo"
      traces[7]['Label'].must_equal "info"
    end
  end
end
