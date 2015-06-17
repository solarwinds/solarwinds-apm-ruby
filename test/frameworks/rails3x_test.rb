require "minitest_helper"

if defined?(::Rails)

  describe "Rails" do
    before do
      clear_all_traces
    end

    it "should trace a request to a rails stack" do

      uri = URI.parse('http://localhost:8140/hello/world')
      r = Net::HTTP.get_response(uri)

      traces = get_all_traces

      traces.count.must_equal 8
      valid_edges?(traces).must_equal true
      validate_outer_layers(traces, 'rack')

      traces[0]['Layer'].must_equal "rack"
      traces[0]['Label'].must_equal "entry"
      traces[0]['URL'].must_equal "/hello/world"

      traces[1]['Layer'].must_equal "rack"
      traces[1]['Label'].must_equal "info"

      traces[2]['Layer'].must_equal "rails"
      traces[2]['Label'].must_equal "entry"

      traces[3]['Label'].must_equal "info"
      traces[3]['Controller'].must_equal "HelloController"
      traces[3]['Action'].must_equal "world"

      traces[4]['Layer'].must_equal "actionview"
      traces[4]['Label'].must_equal "entry"

      traces[5]['Layer'].must_equal "actionview"
      traces[5]['Label'].must_equal "exit"

      traces[6]['Layer'].must_equal "rails"
      traces[6]['Label'].must_equal "exit"

      traces[7]['Layer'].must_equal "rack"
      traces[7]['Label'].must_equal "exit"

      # Validate the existence of the response header
      r.header.key?('X-Trace').must_equal true
      r.header['X-Trace'].must_equal traces[7]['X-Trace']
    end

    it "should trace a request to a rails metal stack" do

      uri = URI.parse('http://localhost:8140/hello/metal')
      r = Net::HTTP.get_response(uri)

      traces = get_all_traces

      traces.count.must_equal 5
      valid_edges?(traces).must_equal true
      validate_outer_layers(traces, 'rack')

      traces[0]['Layer'].must_equal "rack"
      traces[0]['Label'].must_equal "entry"
      traces[0]['URL'].must_equal "/hello/metal"

      traces[1]['Layer'].must_equal "rack"
      traces[1]['Label'].must_equal "info"

      traces[2]['Label'].must_equal "profile_entry"
      traces[2]['Language'].must_equal "ruby"
      traces[2]['ProfileName'].must_equal "world"
      traces[2]['FunctionName'].must_equal "world"
      traces[2]['Class'].must_equal "FerroController"

      traces[3]['Label'].must_equal "profile_exit"
      traces[3]['Language'].must_equal "ruby"
      traces[3]['ProfileName'].must_equal "world"

      traces[4]['Layer'].must_equal "rack"
      traces[4]['Label'].must_equal "exit"

      # Validate the existence of the response header
      r.header.key?('X-Trace').must_equal true
      r.header['X-Trace'].must_equal traces[4]['X-Trace']
    end
  end
end
