# Copyright (c) 2015 AppNeta, Inc.
# All rights reserved.

require "minitest_helper"

if defined?(::Rails)

  describe "Rails3x" do
    before do
      clear_all_traces
    end

    it "should trace a request to a rails stack" do

      uri = URI.parse('http://127.0.0.1:8140/hello/world')
      r = Net::HTTP.get_response(uri)

      traces = get_all_traces

      traces.count.must_equal 8
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

    it "should trace rails db calls" do

      uri = URI.parse('http://127.0.0.1:8140/hello/db')
      r = Net::HTTP.get_response(uri)

      traces = get_all_traces

      traces.count.must_equal 12
      unless defined?(JRUBY_VERSION)
        # We don't test this under JRuby because the Java instrumentation
        # for the DB drivers doesn't use our test reporter hence we won't
        # see all trace events. :-(  To be improved.
        valid_edges?(traces).must_equal true
      end
      validate_outer_layers(traces, 'rack')

      traces[4]['Layer'].must_equal "activerecord"
      traces[4]['Label'].must_equal "entry"
      traces[4]['Flavor'].must_equal "postgresql"
      traces[4]['Query'].must_equal "SELECT \"widgets\".* FROM \"widgets\" "
      traces[4]['Name'].must_equal "Widget Load"
      traces[4].key?('Backtrace').must_equal true

      traces[5]['Layer'].must_equal "activerecord"
      traces[5]['Label'].must_equal "exit"

      traces[6]['Layer'].must_equal "activerecord"
      traces[6]['Label'].must_equal "entry"
      traces[6]['Flavor'].must_equal "postgresql"
      traces[6]['Query'].must_equal "INSERT INTO \"widgets\" (\"created_at\", \"description\", \"name\", \"updated_at\") VALUES ($1, $2, $3, $4) RETURNING \"id\""
      traces[6]['Name'].must_equal "SQL"
      traces[6].key?('Backtrace').must_equal true
      traces[6].key?('QueryArgs').must_equal true

      traces[7]['Layer'].must_equal "activerecord"
      traces[7]['Label'].must_equal "exit"

      # Validate the existence of the response header
      r.header.key?('X-Trace').must_equal true
      r.header['X-Trace'].must_equal traces[11]['X-Trace']
    end
  end
end
