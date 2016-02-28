# Copyright (c) 2015 AppNeta, Inc.
# All rights reserved.

require "minitest_helper"

if defined?(::Rails)

  describe "Rails5x" do
    before do
      clear_all_traces
    end

    it "should trace a request to a rails stack" do

      uri = URI.parse('http://127.0.0.1:8140/hello/world')
      r = Net::HTTP.get_response(uri)

      traces = get_all_traces

      traces.count.must_equal 7
      unless defined?(JRUBY_VERSION)
        # We don't test this under JRuby because the Java instrumentation
        # for the DB drivers doesn't use our test reporter hence we won't
        # see all trace events. :-(  To be improved.
        valid_edges?(traces).must_equal true
      end
      validate_outer_layers(traces, 'rack')

      traces[0]['Layer'].must_equal "rack"
      traces[0]['Label'].must_equal "entry"
      traces[0]['URL'].must_equal "/hello/world"

      traces[1]['Layer'].must_equal "rack"
      traces[1]['Label'].must_equal "info"

      traces[2]['Layer'].must_equal "rails"
      traces[2]['Label'].must_equal "entry"
      traces[2]['Controller'].must_equal "HelloController"
      traces[2]['Action'].must_equal "world"

      traces[3]['Layer'].must_equal "actionview"
      traces[3]['Label'].must_equal "entry"

      traces[4]['Layer'].must_equal "actionview"
      traces[4]['Label'].must_equal "exit"

      traces[5]['Layer'].must_equal "rails"
      traces[5]['Label'].must_equal "exit"

      traces[6]['Layer'].must_equal "rack"
      traces[6]['Label'].must_equal "exit"

      # Validate the existence of the response header
      r.header.key?('X-Trace').must_equal true
      r.header['X-Trace'].must_equal traces[6]['X-Trace']
    end

    it "should trace rails db calls" do
      # Skip for JRuby since the java instrumentation
      # handles DB instrumentation for JRuby
      skip if defined?(JRUBY_VERSION)

      uri = URI.parse('http://127.0.0.1:8140/hello/db')
      r = Net::HTTP.get_response(uri)

      traces = get_all_traces

      traces.count.must_equal 11
      valid_edges?(traces).must_equal true
      validate_outer_layers(traces, 'rack')

      traces[3]['Layer'].must_equal "activerecord"
      traces[3]['Label'].must_equal "entry"
      traces[3]['Flavor'].must_equal "postgresql"
      traces[3]['Query'].must_equal "SELECT  \"widgets\".* FROM \"widgets\"  ORDER BY \"widgets\".\"id\" ASC LIMIT 1"
      traces[3]['Name'].must_equal "Widget Load"
      traces[3].key?('Backtrace').must_equal true

      traces[4]['Layer'].must_equal "activerecord"
      traces[4]['Label'].must_equal "exit"

      traces[5]['Layer'].must_equal "activerecord"
      traces[5]['Label'].must_equal "entry"
      traces[5]['Flavor'].must_equal "postgresql"
      traces[5]['Query'].must_equal "INSERT INTO \"widgets\" (\"name\", \"description\", \"created_at\", \"updated_at\") VALUES ($1, $2, $3, $4) RETURNING \"id\""
      traces[5]['Name'].must_equal "SQL"
      traces[5].key?('Backtrace').must_equal true
      traces[5].key?('QueryArgs').must_equal true

      traces[6]['Layer'].must_equal "activerecord"
      traces[6]['Label'].must_equal "exit"

      # Validate the existence of the response header
      r.header.key?('X-Trace').must_equal true
      r.header['X-Trace'].must_equal traces[10]['X-Trace']
    end

    it "should trace a request to a rails metal stack" do

      uri = URI.parse('http://127.0.0.1:8140/hello/metal')
      r = Net::HTTP.get_response(uri)

      traces = get_all_traces

      traces.count.must_equal 5
      unless defined?(JRUBY_VERSION)
        # We don't test this under JRuby because the Java instrumentation
        # for the DB drivers doesn't use our test reporter hence we won't
        # see all trace events. :-(  To be improved.
        valid_edges?(traces).must_equal true
      end
      validate_outer_layers(traces, 'rack')

      traces[0]['Layer'].must_equal "rack"
      traces[0]['Label'].must_equal "entry"
      traces[0]['URL'].must_equal "/hello/metal"

      traces[1]['Layer'].must_equal "rack"
      traces[1]['Label'].must_equal "info"

      traces[2]['Label'].must_equal "profile_entry"
      traces[2]['Language'].must_equal "ruby"
      traces[2]['ProfileName'].must_equal "world"
      traces[2]['MethodName'].must_equal "world"
      traces[2]['Class'].must_equal "FerroController"
      traces[2]['Controller'].must_equal "FerroController"
      traces[2]['Action'].must_equal "world"

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
