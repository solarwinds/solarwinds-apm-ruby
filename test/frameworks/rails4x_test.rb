# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require "minitest_helper"

if defined?(::Rails)

  describe "Rails4x" do
    before do
      clear_all_traces
      AppOpticsAPM.config_lock.synchronize {
        @tm = AppOpticsAPM::Config[:tracing_mode]
        @collect_backtraces = AppOpticsAPM::Config[:action_controller][:collect_backtraces]
        @sample_rate = AppOpticsAPM::Config[:sample_rate]
        @sanitize_sql = AppOpticsAPM::Config[:sanitize_sql]

        AppOpticsAPM::Config[:action_controller][:collect_backtraces] = false
        AppOpticsAPM::Config[:active_record][:collect_backtraces] = false
        AppOpticsAPM::Config[:rack][:collect_backtraces] = false
      }
      ENV['DBTYPE'] = "postgresql" unless ENV['DBTYPE']
    end

    after do
      AppOpticsAPM.config_lock.synchronize {
        AppOpticsAPM::Config[:action_controller][:collect_backtraces] = @collect_backtraces
        AppOpticsAPM::Config[:tracing_mode] = @tm
        AppOpticsAPM::Config[:sample_rate] = @sample_rate
        AppOpticsAPM::Config[:sanitize_sql] = @sanitize_sql
      }
    end

    it "should trace a request to a rails stack" do

      uri = URI.parse('http://127.0.0.1:8140/hello/world')
      r = Net::HTTP.get_response(uri)

      traces = get_all_traces

      traces.count.must_equal 6
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

      traces[1]['Layer'].must_equal "rails"
      traces[1]['Label'].must_equal "entry"
      traces[1]['Controller'].must_equal "HelloController"
      traces[1]['Action'].must_equal "world"

      traces[2]['Layer'].must_equal "actionview"
      traces[2]['Label'].must_equal "entry"

      traces[3]['Layer'].must_equal "actionview"
      traces[3]['Label'].must_equal "exit"

      traces[4]['Layer'].must_equal "rails"
      traces[4]['Label'].must_equal "exit"

      traces[5]['Layer'].must_equal "rack"
      traces[5]['Label'].must_equal "exit"

      # Validate the existence of the response header
      r.header.key?('X-Trace').must_equal true
      r.header['X-Trace'].must_equal traces[5]['X-Trace']
    end

    it "should trace rails postgres db calls" do
      # Skip for JRuby since the java instrumentation
      # handles DB instrumentation for JRuby
      skip if defined?(JRUBY_VERSION) || ENV['DBTYPE'] != 'postgresql'

      uri = URI.parse('http://127.0.0.1:8140/hello/db')
      r = Net::HTTP.get_response(uri)

      traces = get_all_traces

      traces.count.must_equal 12
      valid_edges?(traces).must_equal true
      validate_outer_layers(traces, 'rack')

      traces[2]['Layer'].must_equal "activerecord"
      traces[2]['Label'].must_equal "entry"
      traces[2]['Flavor'].must_equal "postgresql"
      traces[2]['Name'].must_equal "SQL"
      traces[2].key?('Backtrace').must_equal false

      # Use a regular expression to test the SQL string since field order varies between
      # Rails versions
      match_data = traces[2]['Query']
      match_data.must_equal("INSERT INTO \"widgets\" (\"name\", \"description\", \"created_at\", \"updated_at\") VALUES ($?, $?, $?, $?) RETURNING \"id\"")

      traces[3]['Layer'].must_equal "activerecord"
      traces[3]['Label'].must_equal "exit"

      traces[4]['Layer'].must_equal "activerecord"
      traces[4]['Label'].must_equal "entry"
      traces[4]['Flavor'].must_equal "postgresql"

      # Some versions of rails adds in another space before the ORDER keyword.
      # Make 2 or more consecutive spaces just 1
      sql = traces[4]['Query'].gsub(/\s{2,}/, ' ')
      sql.must_equal "SELECT \"widgets\".* FROM \"widgets\" WHERE \"widgets\".\"name\" = $? ORDER BY \"widgets\".\"id\" ASC LIMIT ?"

      traces[4]['Name'].must_equal "Widget Load"
      traces[4].key?('Backtrace').must_equal false
      traces[4].key?('QueryArgs').must_equal false

      traces[5]['Layer'].must_equal "activerecord"
      traces[5]['Label'].must_equal "exit"

      traces[6]['Layer'].must_equal "activerecord"
      traces[6]['Label'].must_equal "entry"
      traces[6]['Flavor'].must_equal "postgresql"
      traces[6]['Query'].must_equal "DELETE FROM \"widgets\" WHERE \"widgets\".\"id\" = $?"
      traces[6]['Name'].must_equal "SQL"
      traces[6].key?('Backtrace').must_equal false
      traces[6].key?('QueryArgs').must_equal false

      traces[7]['Layer'].must_equal "activerecord"
      traces[7]['Label'].must_equal "exit"

      # Validate the existence of the response header
      r.header.key?('X-Trace').must_equal true
      r.header['X-Trace'].must_equal traces[11]['X-Trace']
    end

    it "should trace rails mysql db calls" do
      # Skip for JRuby since the java instrumentation
      # handles DB instrumentation for JRuby
      skip if defined?(JRUBY_VERSION) || ENV['DBTYPE'] != "mysql"

      AppOpticsAPM::Config[:sanitize_sql] = false

      uri = URI.parse('http://127.0.0.1:8140/hello/db')
      r = Net::HTTP.get_response(uri)

      traces = get_all_traces

      traces.count.must_equal 16
      valid_edges?(traces).must_equal true
      validate_outer_layers(traces, 'rack')

      traces[2]['Layer'].must_equal "activerecord"
      traces[2]['Label'].must_equal "entry"
      traces[2]['Flavor'].must_equal "mysql"
      traces[2]['Query'].must_equal "BEGIN"
      traces[2].key?('Backtrace').must_equal false

      traces[3]['Layer'].must_equal "activerecord"
      traces[3]['Label'].must_equal "exit"

      traces[4]['Layer'].must_equal "activerecord"
      traces[4]['Label'].must_equal "entry"
      traces[4]['Flavor'].must_equal "mysql"
      traces[4]['Query'].must_equal "INSERT INTO `widgets` (`name`, `description`, `created_at`, `updated_at`) VALUES (?, ?, ?, ?)"
      traces[4]['Name'].must_equal "SQL"
      traces[4].key?('Backtrace').must_equal false
      traces[4].key?('QueryArgs').must_equal true

      traces[5]['Layer'].must_equal "activerecord"
      traces[5]['Label'].must_equal "exit"

      traces[6]['Layer'].must_equal "activerecord"
      traces[6]['Label'].must_equal "entry"
      traces[6]['Flavor'].must_equal "mysql"
      traces[6]['Query'].must_equal "COMMIT"
      traces[6].key?('Backtrace').must_equal false

      traces[7]['Layer'].must_equal "activerecord"
      traces[7]['Label'].must_equal "exit"

      traces[8]['Layer'].must_equal "activerecord"
      traces[8]['Label'].must_equal "entry"
      traces[8]['Flavor'].must_equal "mysql"
      traces[8]['Name'].must_equal "Widget Load"
      traces[8].key?('Backtrace').must_equal false

      # Some versions of rails adds in another space before the ORDER keyword.
      # Make 2 or more consecutive spaces just 1
      sql = traces[8]['Query'].gsub(/\s{2,}/, ' ')
      sql.must_equal "SELECT `widgets`.* FROM `widgets` WHERE `widgets`.`name` = ? ORDER BY `widgets`.`id` ASC LIMIT 1"

      traces[9]['Layer'].must_equal "activerecord"
      traces[9]['Label'].must_equal "exit"

      traces[10]['Layer'].must_equal "activerecord"
      traces[10]['Label'].must_equal "entry"
      traces[10]['Flavor'].must_equal "mysql"
      traces[10]['Name'].must_equal "SQL"
      traces[10].key?('Backtrace').must_equal false
      traces[10].key?('QueryArgs').must_equal true
      traces[10]['Query'].must_equal "DELETE FROM `widgets` WHERE `widgets`.`id` = ?"

      traces[11]['Layer'].must_equal "activerecord"
      traces[11]['Label'].must_equal "exit"

      traces[12]['Layer'].must_equal "actionview"
      traces[12]['Label'].must_equal "entry"

      # Validate the existence of the response header
      r['X-Trace'].must_equal traces[15]['X-Trace']
    end

    it "should trace rails mysql db calls with sanitize sql" do
      # Skip for JRuby since the java instrumentation
      # handles DB instrumentation for JRuby
      skip if defined?(JRUBY_VERSION) || ENV['DBTYPE'] != "mysql"

      AppOpticsAPM::Config[:sanitize_sql] = true

      uri = URI.parse('http://127.0.0.1:8140/hello/db')
      r = Net::HTTP.get_response(uri)

      traces = get_all_traces

      traces.count.must_equal 16
      valid_edges?(traces).must_equal true
      validate_outer_layers(traces, 'rack')

      traces[2]['Layer'].must_equal "activerecord"
      traces[2]['Label'].must_equal "entry"
      traces[2]['Flavor'].must_equal "mysql"
      traces[2]['Query'].must_equal "BEGIN"
      traces[2].key?('Backtrace').must_equal false

      traces[3]['Layer'].must_equal "activerecord"
      traces[3]['Label'].must_equal "exit"

      traces[4]['Layer'].must_equal "activerecord"
      traces[4]['Label'].must_equal "entry"
      traces[4]['Flavor'].must_equal "mysql"
      traces[4]['Query'].must_equal "INSERT INTO `widgets` (`name`, `description`, `created_at`, `updated_at`) VALUES (?, ?, ?, ?)"
      traces[4]['Name'].must_equal "SQL"
      traces[4].key?('Backtrace').must_equal false
      traces[4].key?('QueryArgs').must_equal false

      traces[5]['Layer'].must_equal "activerecord"
      traces[5]['Label'].must_equal "exit"

      traces[6]['Layer'].must_equal "activerecord"
      traces[6]['Label'].must_equal "entry"
      traces[6]['Flavor'].must_equal "mysql"
      traces[6]['Query'].must_equal "COMMIT"
      traces[6].key?('Backtrace').must_equal false

      traces[7]['Layer'].must_equal "activerecord"
      traces[7]['Label'].must_equal "exit"

      traces[8]['Layer'].must_equal "activerecord"
      traces[8]['Label'].must_equal "entry"
      traces[8]['Flavor'].must_equal "mysql"
      traces[8]['Name'].must_equal "Widget Load"
      traces[8].key?('Backtrace').must_equal false

      # Some versions of rails adds in another space before the ORDER keyword.
      # Make 2 or more consecutive spaces just 1
      sql = traces[8]['Query'].gsub(/\s{2,}/, ' ')
      sql.must_equal "SELECT `widgets`.* FROM `widgets` WHERE `widgets`.`name` = ? ORDER BY `widgets`.`id` ASC LIMIT ?"

      traces[9]['Layer'].must_equal "activerecord"
      traces[9]['Label'].must_equal "exit"

      traces[10]['Layer'].must_equal "activerecord"
      traces[10]['Label'].must_equal "entry"
      traces[10]['Flavor'].must_equal "mysql"
      traces[10]['Name'].must_equal "SQL"
      traces[10].key?('Backtrace').must_equal false
      traces[10].key?('QueryArgs').must_equal false
      traces[10]['Query'].must_equal "DELETE FROM `widgets` WHERE `widgets`.`id` = ?"

      traces[11]['Layer'].must_equal "activerecord"
      traces[11]['Label'].must_equal "exit"

      traces[12]['Layer'].must_equal "actionview"
      traces[12]['Label'].must_equal "entry"

      # Validate the existence of the response header
      r['X-Trace'].must_equal traces[15]['X-Trace']
    end

    it "should trace rails mysql2 db calls" do
      # Skip for JRuby since the java instrumentation
      # handles DB instrumentation for JRuby
      skip if defined?(JRUBY_VERSION) || ENV['DBTYPE'] != "mysql2"

      AppOpticsAPM::Config[:sanitize_sql] = false

      uri = URI.parse('http://127.0.0.1:8140/hello/db')
      r = Net::HTTP.get_response(uri)

      traces = get_all_traces

      traces.count.must_equal 12
      valid_edges?(traces).must_equal true
      validate_outer_layers(traces, 'rack')

      traces[2]['Layer'].must_equal "activerecord"
      traces[2]['Label'].must_equal "entry"
      traces[2]['Flavor'].must_equal "mysql"

      # Replace the datestamps with xxx to make testing easier
      traces[2]['Query'].gsub!(/\d\d\d\d-\d\d-\d\d\s\d\d:\d\d:\d\d/, 'xxx')
      traces[2]['Query'].must_equal "INSERT INTO `widgets` (`name`, `description`, `created_at`, `updated_at`) VALUES ('blah', 'This is an amazing widget.', 'xxx', 'xxx')"

      traces[2]['Name'].must_equal "SQL"
      traces[2].key?('Backtrace').must_equal false
      traces[2].key?('QueryArgs').must_equal true

      traces[3]['Layer'].must_equal "activerecord"
      traces[3]['Label'].must_equal "exit"

      traces[4]['Layer'].must_equal "activerecord"
      traces[4]['Label'].must_equal "entry"
      traces[4]['Flavor'].must_equal "mysql"
      traces[4]['Query'].must_equal "SELECT  `widgets`.* FROM `widgets` WHERE `widgets`.`name` = 'blah'  ORDER BY `widgets`.`id` ASC LIMIT 1"
      traces[4]['Name'].must_equal "Widget Load"
      traces[4].key?('Backtrace').must_equal false
      traces[4].key?('QueryArgs').must_equal true

      traces[5]['Layer'].must_equal "activerecord"
      traces[5]['Label'].must_equal "exit"

      traces[6]['Layer'].must_equal "activerecord"
      traces[6]['Label'].must_equal "entry"
      traces[6]['Flavor'].must_equal "mysql"
      traces[6]['Name'].must_equal "SQL"
      traces[6].key?('Backtrace').must_equal false

      sql = traces[6]['Query'].gsub(/\d+/, 'xxx')
      sql.must_equal "DELETE FROM `widgets` WHERE `widgets`.`id` = xxx"

      traces[7]['Layer'].must_equal "activerecord"
      traces[7]['Label'].must_equal "exit"

      # Validate the existence of the response header
      r['X-Trace'].must_equal traces[11]['X-Trace']
    end

    it "should trace rails mysql2 db calls with santize sql" do
      # Skip for JRuby since the java instrumentation
      # handles DB instrumentation for JRuby
      skip if defined?(JRUBY_VERSION) || ENV['DBTYPE'] != "mysql2"

      AppOpticsAPM::Config[:sanitize_sql] = true

      uri = URI.parse('http://127.0.0.1:8140/hello/db')
      r = Net::HTTP.get_response(uri)

      traces = get_all_traces

      traces.count.must_equal 12
      valid_edges?(traces).must_equal true
      validate_outer_layers(traces, 'rack')

      traces[2]['Layer'].must_equal "activerecord"
      traces[2]['Label'].must_equal "entry"
      traces[2]['Flavor'].must_equal "mysql"

      # Replace the datestamps with xxx to make testing easier
      traces[2]['Query'].must_equal "INSERT INTO `widgets` (`name`, `description`, `created_at`, `updated_at`) VALUES (?, ?, ?, ?)"

      traces[2]['Name'].must_equal "SQL"
      traces[2].key?('Backtrace').must_equal false
      traces[2].key?('QueryArgs').must_equal false

      traces[3]['Layer'].must_equal "activerecord"
      traces[3]['Label'].must_equal "exit"

      traces[4]['Layer'].must_equal "activerecord"
      traces[4]['Label'].must_equal "entry"
      traces[4]['Flavor'].must_equal "mysql"
      traces[4]['Query'].must_equal "SELECT  `widgets`.* FROM `widgets` WHERE `widgets`.`name` = ?  ORDER BY `widgets`.`id` ASC LIMIT ?"
      traces[4]['Name'].must_equal "Widget Load"
      traces[4].key?('Backtrace').must_equal false
      traces[4].key?('QueryArgs').must_equal false

      traces[5]['Layer'].must_equal "activerecord"
      traces[5]['Label'].must_equal "exit"

      traces[6]['Layer'].must_equal "activerecord"
      traces[6]['Label'].must_equal "entry"
      traces[6]['Flavor'].must_equal "mysql"
      traces[6]['Name'].must_equal "SQL"
      traces[6].key?('Backtrace').must_equal false

      traces[6]['Query'].must_equal "DELETE FROM `widgets` WHERE `widgets`.`id` = ?"

      traces[7]['Layer'].must_equal "activerecord"
      traces[7]['Label'].must_equal "exit"

      # Validate the existence of the response header
      r['X-Trace'].must_equal traces[11]['X-Trace']
    end

    it "should trace a request to a rails metal stack" do
      uri = URI.parse('http://127.0.0.1:8140/hello/metal')
      r = Net::HTTP.get_response(uri)

      traces = get_all_traces

      traces.count.must_equal 4
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

      traces[1]['Label'].must_equal "profile_entry"
      traces[1]['Language'].must_equal "ruby"
      traces[1]['ProfileName'].must_equal "world"
      traces[1]['MethodName'].must_equal "world"
      traces[1]['Class'].must_equal "FerroController"
      traces[1]['Controller'].must_equal "FerroController"
      traces[1]['Action'].must_equal "world"

      traces[2]['Label'].must_equal "profile_exit"
      traces[2]['Language'].must_equal "ruby"
      traces[2]['ProfileName'].must_equal "world"

      traces[3]['Layer'].must_equal "rack"
      traces[3]['Label'].must_equal "exit"

      # Validate the existence of the response header
      r['X-Trace'].must_equal traces[3]['X-Trace']
    end

    it "should collect backtraces when true" do
      AppOpticsAPM::Config[:action_controller][:collect_backtraces] = true

      uri = URI.parse('http://127.0.0.1:8140/hello/world')
      r = Net::HTTP.get_response(uri)

      traces = get_all_traces

      traces.count.must_equal 6
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

      traces[1]['Layer'].must_equal "rails"
      traces[1]['Label'].must_equal "entry"
      traces[1]['Controller'].must_equal "HelloController"
      traces[1]['Action'].must_equal "world"
      traces[1].key?('Backtrace').must_equal true

      traces[2]['Layer'].must_equal "actionview"
      traces[2]['Label'].must_equal "entry"

      traces[3]['Layer'].must_equal "actionview"
      traces[3]['Label'].must_equal "exit"

      traces[4]['Layer'].must_equal "rails"
      traces[4]['Label'].must_equal "exit"

      traces[5]['Layer'].must_equal "rack"
      traces[5]['Label'].must_equal "exit"

      # Validate the existence of the response header
      r['X-Trace'].must_equal traces[5]['X-Trace']
    end

    it "should NOT collect backtraces when false" do
      AppOpticsAPM::Config[:action_controller][:collect_backtraces] = false

      uri = URI.parse('http://127.0.0.1:8140/hello/world')
      r = Net::HTTP.get_response(uri)

      traces = get_all_traces

      traces.count.must_equal 6
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

      traces[1]['Layer'].must_equal "rails"
      traces[1]['Label'].must_equal "entry"
      traces[1]['Controller'].must_equal "HelloController"
      traces[1]['Action'].must_equal "world"
      traces[1].key?('Backtrace').must_equal false

      traces[2]['Layer'].must_equal "actionview"
      traces[2]['Label'].must_equal "entry"

      traces[3]['Layer'].must_equal "actionview"
      traces[3]['Label'].must_equal "exit"

      traces[4]['Layer'].must_equal "rails"
      traces[4]['Label'].must_equal "exit"

      traces[5]['Layer'].must_equal "rack"
      traces[5]['Label'].must_equal "exit"

      # Validate the existence of the response header
      r['X-Trace'].must_equal traces[5]['X-Trace']
    end

    it "should NOT trace when tracing is set to :disabled" do
      AppOpticsAPM.config_lock.synchronize do
        AppOpticsAPM::Config[:tracing_mode] = :disabled
        uri = URI.parse('http://127.0.0.1:8140/hello/world')
        r = Net::HTTP.get_response(uri)

        traces = get_all_traces
        traces.count.must_equal 0
      end
    end

    it "should NOT trace when sample_rate is 0" do
      AppOpticsAPM.config_lock.synchronize do
        AppOpticsAPM::Config[:sample_rate] = 0
        uri = URI.parse('http://127.0.0.1:8140/hello/world')
        r = Net::HTTP.get_response(uri)

        traces = get_all_traces
        traces.count.must_equal 0
      end
    end

    it "should NOT trace when there is no context" do
      response_headers = HelloController.action("world").call(
          "REQUEST_METHOD" => "GET",
          "rack.input" => -> {}
      )[1]

      response_headers['X-Trace'].must_be_nil

      traces = get_all_traces
      traces.count.must_equal 0
    end

    require_relative "rails_shared_tests"
    require_relative "rails_crud_test"
    require_relative 'rails_logger_formatter_test'
  end
end
