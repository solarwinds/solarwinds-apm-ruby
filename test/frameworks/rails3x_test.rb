# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require "minitest_helper"

if defined?(::Rails)

  describe "Rails3x" do
    before do
      clear_all_traces
      AppOptics.config_lock.synchronize {
        @tm = AppOptics::Config[:tracing_mode]
        @collect_backtraces = AppOptics::Config[:action_controller][:collect_backtraces]
        @sample_rate = AppOptics::Config[:sample_rate]
      }
      ENV['DBTYPE'] = "postgresql" unless ENV['DBTYPE']
      ENV['TEST_DB_URI'] ||= 'http://127.0.0.1:8140'
    end

    after do
      AppOptics.config_lock.synchronize {
        AppOptics::Config[:action_controller][:collect_backtraces] = @collect_backtraces
        AppOptics::Config[:tracing_mode] = @tm
        AppOptics::Config[:sample_rate] = @sample_rate
      }
    end

    it "should trace a request to a rails stack" do

      uri = URI.parse("#{ENV['TEST_DB_URI']}/hello/world")
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

      uri = URI.parse("#{ENV['TEST_DB_URI']}/hello/metal")
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

    # TODO: should we have this test for other rails versions as well?
    # TODO: review this test and why it fails (sometimes?)
    it "should trace rails postgresql db calls" do
      # Skip for JRuby since the java instrumentation
      # handles DB instrumentation for JRuby
      skip if defined?(JRUBY_VERSION) || ENV['DBTYPE'] != "postgresql"

      uri = URI.parse('http://127.0.0.1:8140/hello/db')
      r = Net::HTTP.get_response(uri)

      traces = get_all_traces

      traces.count.must_equal 14
      valid_edges?(traces).must_equal true
      validate_outer_layers(traces, 'rack')

      traces[4]['Layer'].must_equal "activerecord"
      traces[4]['Label'].must_equal "entry"
      traces[4]['Flavor'].must_equal "postgresql"

      # Some versions of rails adds in another space before the ORDER keyword.
      # Make 2 or more consecutive spaces just 1
      sql = traces[4]['Query'].gsub(/\s{2,}/, ' ')
      sql.must_equal "INSERT INTO \"widgets\" (\"created_at\", \"description\", \"name\", \"updated_at\") VALUES ($1, $2, $3, $4) RETURNING \"id\""

      traces[4]['Name'].must_equal "SQL"
      traces[4].key?('Backtrace').must_equal true

      traces[5]['Layer'].must_equal "activerecord"
      traces[5]['Label'].must_equal "exit"

      traces[6]['Layer'].must_equal "activerecord"
      traces[6]['Label'].must_equal "entry"
      traces[6]['Flavor'].must_equal "postgresql"
      traces[6]['Query'].must_equal "SELECT  \"widgets\".* FROM \"widgets\"  WHERE \"widgets\".\"name\" = 'blah' LIMIT 1"
      traces[6]['Name'].must_equal "Widget Load"
      traces[6].key?('Backtrace').must_equal true
      traces[6].key?('QueryArgs').must_equal false

      traces[7]['Layer'].must_equal "activerecord"
      traces[7]['Label'].must_equal "exit"

      traces[8]['Layer'].must_equal "activerecord"
      traces[8]['Label'].must_equal "entry"
      traces[8]['Flavor'].must_equal "postgresql"

      # Remove the widget id so we can test everything else
      sql = traces[8]['Query'].gsub(/\d+/, 'xxx')
      sql.must_equal "DELETE FROM \"widgets\" WHERE \"widgets\".\"id\" = xxx"

      traces[8]['Name'].must_equal "SQL"
      traces[8].key?('Backtrace').must_equal true
      traces[8].key?('QueryArgs').must_equal false

      traces[9]['Layer'].must_equal "activerecord"
      traces[9]['Label'].must_equal "exit"

      # Validate the existence of the response header
      r['X-Trace'].must_equal traces[13]['X-Trace']
    end

    it "should trace rails mysql db calls" do
      # Skip for JRuby since the java instrumentation
      # handles DB instrumentation for JRuby
      skip if defined?(JRUBY_VERSION) || ENV['DBTYPE'] != "mysql"

      uri = URI.parse("#{ENV['TEST_DB_URI']}/hello/db")
      r = Net::HTTP.get_response(uri)

      traces = get_all_traces

      traces.count.must_equal 18
      valid_edges?(traces).must_equal true
      validate_outer_layers(traces, 'rack')

      traces[4]['Layer'].must_equal "activerecord"
      traces[4]['Label'].must_equal "entry"
      traces[4]['Flavor'].must_equal "mysql"
      traces[4]['Query'].must_equal "BEGIN"
      traces[4].key?('Backtrace').must_equal true

      traces[5]['Layer'].must_equal "activerecord"
      traces[5]['Label'].must_equal "exit"

      traces[6]['Layer'].must_equal "activerecord"
      traces[6]['Label'].must_equal "entry"
      traces[6]['Flavor'].must_equal "mysql"
      traces[6]['Query'].must_equal "INSERT INTO `widgets` (`created_at`, `description`, `name`, `updated_at`) VALUES (?, ?, ?, ?)"
      traces[6]['Name'].must_equal "SQL"
      traces[6].key?('Backtrace').must_equal true
      traces[6].key?('QueryArgs').must_equal true

      traces[7]['Layer'].must_equal "activerecord"
      traces[7]['Label'].must_equal "exit"

      traces[8]['Layer'].must_equal "activerecord"
      traces[8]['Label'].must_equal "entry"
      traces[8]['Flavor'].must_equal "mysql"
      traces[8]['Query'].must_equal "COMMIT"
      traces[8].key?('Backtrace').must_equal true

      traces[9]['Layer'].must_equal "activerecord"
      traces[9]['Label'].must_equal "exit"

      traces[10]['Layer'].must_equal "activerecord"
      traces[10]['Label'].must_equal "entry"
      traces[10]['Flavor'].must_equal "mysql"
      traces[10]['Name'].must_equal "Widget Load"
      traces[10].key?('Backtrace').must_equal true

      # Some versions of rails adds in another space before the ORDER keyword.
      # Make 2 or more consecutive spaces just 1
      sql = traces[10]['Query'].gsub(/\s{2,}/, ' ')
      sql.must_equal "SELECT `widgets`.* FROM `widgets` WHERE `widgets`.`name` = 'blah' LIMIT 1"

      traces[11]['Layer'].must_equal "activerecord"
      traces[11]['Label'].must_equal "exit"

      traces[12]['Layer'].must_equal "activerecord"
      traces[12]['Label'].must_equal "entry"
      traces[12]['Flavor'].must_equal "mysql"
      traces[12]['Name'].must_equal "SQL"
      traces[12].key?('Backtrace').must_equal true
      traces[12].key?('QueryArgs').must_equal false

      # Replace the datestamps with xxx to make testing easier
      sql = traces[12]['Query'].gsub(/\d+/, 'xxx')
      sql.must_equal "DELETE FROM `widgets` WHERE `widgets`.`id` = xxx"

      traces[13]['Layer'].must_equal "activerecord"
      traces[13]['Label'].must_equal "exit"

      traces[14]['Layer'].must_equal "actionview"
      traces[14]['Label'].must_equal "entry"

      # Validate the existence of the response header
      r['X-Trace'].must_equal traces[17]['X-Trace']
    end

    it "should trace rails mysql2 db calls" do
      # Skip for JRuby since the java instrumentation
      # handles DB instrumentation for JRuby
      skip if defined?(JRUBY_VERSION) || ENV['DBTYPE'] != 'mysql2'

      uri = URI.parse("#{ENV['TEST_DB_URI']}/hello/db")
      r = Net::HTTP.get_response(uri)

      traces = get_all_traces

      traces.count.must_equal 14
      valid_edges?(traces).must_equal true
      validate_outer_layers(traces, 'rack')

      traces[4]['Layer'].must_equal "activerecord"
      traces[4]['Label'].must_equal "entry"
      traces[4]['Flavor'].must_equal "mysql"

      # Replace the datestamps with xxx to make testing easier
      sql = traces[4]['Query'].gsub(/\d\d\d\d-\d\d-\d\d\s\d\d:\d\d:\d\d/, 'xxx')
      sql.must_equal "INSERT INTO `widgets` (`created_at`, `description`, `name`, `updated_at`) VALUES ('xxx', 'This is an amazing widget.', 'blah', 'xxx')"

      traces[4]['Name'].must_equal "SQL"
      traces[4].key?('Backtrace').must_equal true

      traces[5]['Layer'].must_equal "activerecord"
      traces[5]['Label'].must_equal "exit"

      traces[6]['Layer'].must_equal "activerecord"
      traces[6]['Label'].must_equal "entry"
      traces[6]['Flavor'].must_equal "mysql"
      traces[6]['Query'].must_equal "SELECT  `widgets`.* FROM `widgets`  WHERE `widgets`.`name` = 'blah' LIMIT 1"
      traces[6]['Name'].must_equal "Widget Load"
      traces[6].key?('Backtrace').must_equal true
      traces[6].key?('QueryArgs').must_equal false

      traces[7]['Layer'].must_equal "activerecord"
      traces[7]['Label'].must_equal "exit"

      traces[8]['Layer'].must_equal "activerecord"
      traces[8]['Label'].must_equal "entry"
      traces[8]['Flavor'].must_equal "mysql"

      # Replace the datestamps with xxx to make testing easier
      sql = traces[8]['Query'].gsub(/\d+/, 'xxx')
      sql.must_equal "DELETE FROM `widgets` WHERE `widgets`.`id` = xxx"

      traces[8]['Name'].must_equal "SQL"
      traces[8].key?('Backtrace').must_equal true
      traces[8].key?('QueryArgs').must_equal false

      traces[9]['Layer'].must_equal "activerecord"
      traces[9]['Label'].must_equal "exit"

      # Validate the existence of the response header
      r.header.key?('X-Trace').must_equal true
      r.header['X-Trace'].must_equal traces[13]['X-Trace']
    end

    it "should collect backtraces when true" do

      AppOptics::Config[:action_controller][:collect_backtraces] = true

      uri = URI.join(ENV['TEST_DB_URI'], '/hello/world')
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
      traces[3].key?('Backtrace').must_equal true

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

    it "should NOT collect backtraces when false" do

      AppOptics::Config[:action_controller][:collect_backtraces] = false

      uri = URI.parse("#{ENV['TEST_DB_URI']}/hello/world")
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
      traces[3].key?('Backtrace').must_equal false

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

    require_relative "rails_shared_tests"
  end
end
