# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require "minitest_helper"

if defined?(::Rails)

  describe "Rails5x" do
    before do
      clear_all_traces
      AppOpticsAPM.config_lock.synchronize {
        @tm = AppOpticsAPM::Config[:tracing_mode]
        @collect_backtraces = AppOpticsAPM::Config[:action_controller][:collect_backtraces]
        @collect_ar_backtraces = AppOpticsAPM::Config[:active_record][:collect_backtraces]
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
        AppOpticsAPM::Config[:active_record][:collect_backtraces] = @collect_ar_backtraces
        AppOpticsAPM::Config[:tracing_mode] = @tm
        AppOpticsAPM::Config[:sample_rate] = @sample_rate
        AppOpticsAPM::Config[:sanitize_sql] = @sanitize_sql
      }
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

    # Different behavior in Rails >= 5.2.0
    # https://github.com/rails/rails/pull/30619
    it "should trace rails postgres db calls" do
      # Skip for JRuby since the java instrumentation
      # handles DB instrumentation for JRuby
      skip if defined?(JRUBY_VERSION) || ENV['DBTYPE'] != 'postgresql'

      uri = URI.parse('http://127.0.0.1:8140/hello/db')
      r = Net::HTTP.get_response(uri)

      traces = get_all_traces

      traces.count.must_equal 13
      valid_edges?(traces).must_equal true
      validate_outer_layers(traces, 'rack')

      traces[3]['Layer'].must_equal "activerecord"
      traces[3]['Label'].must_equal "entry"
      traces[3]['Flavor'].must_equal "postgresql"
      traces[3]['Query'].must_equal "INSERT INTO \"widgets\" (\"name\", \"description\", \"created_at\", \"updated_at\") VALUES ($?, $?, $?, $?) RETURNING \"id\""
      traces[3]['Name'].must_equal Rails.version < '5.2.0' ? "SQL" : "Widget Create"
      traces[3].key?('Backtrace').must_equal false

      traces[4]['Layer'].must_equal "activerecord"
      traces[4]['Label'].must_equal "exit"

      traces[5]['Layer'].must_equal "activerecord"
      traces[5]['Label'].must_equal "entry"
      traces[5]['Flavor'].must_equal "postgresql"
      traces[5]['Query'].must_equal "SELECT  \"widgets\".* FROM \"widgets\" WHERE \"widgets\".\"name\" = $? ORDER BY \"widgets\".\"id\" ASC LIMIT $?"
      traces[5]['Name'].must_equal "Widget Load"
      traces[5].key?('Backtrace').must_equal false
      traces[5].key?('QueryArgs').must_equal false

      traces[6]['Layer'].must_equal "activerecord"
      traces[6]['Label'].must_equal "exit"

      traces[7]['Layer'].must_equal "activerecord"
      traces[7]['Label'].must_equal "entry"
      traces[7]['Flavor'].must_equal "postgresql"
      traces[7]['Query'].must_equal "DELETE FROM \"widgets\" WHERE \"widgets\".\"id\" = $?"
      traces[7]['Name'].must_equal Rails.version < '5.2.0' ? "SQL" : "Widget Destroy"
      traces[7].key?('Backtrace').must_equal false
      traces[7].key?('QueryArgs').must_equal false

      traces[8]['Layer'].must_equal "activerecord"
      traces[8]['Label'].must_equal "exit"

      # Validate the existence of the response header
      r.header.key?('X-Trace').must_equal true
      r.header['X-Trace'].must_equal traces[12]['X-Trace']
    end

    # Different behavior in Rails >= 5.2.0
    # https://github.com/rails/rails/pull/30619
    # and
    # https://github.com/rails/rails/commit/213796fb4936dce1da2f0c097a054e1af5c25c2c
    it "should trace rails mysql2 db calls" do
      # Skip for JRuby since the java instrumentation
      # handles DB instrumentation for JRuby
      skip if defined?(JRUBY_VERSION) || ENV['DBTYPE'] != 'mysql2'

      AppOpticsAPM::Config[:sanitize_sql] = false

      uri = URI.parse('http://127.0.0.1:8140/hello/db')
      r = Net::HTTP.get_response(uri)

      traces = get_all_traces
      traces.count.must_equal 13
      valid_edges?(traces).must_equal true
      validate_outer_layers(traces, 'rack')

      entry_traces = traces.select { |tr| tr['Label'] == 'entry' }
      entry_traces.count.must_equal 6

      exit_traces = traces.select { |tr| tr['Label'] == 'exit' }
      exit_traces.count.must_equal 6

      entry_traces[2]['Layer'].must_equal "activerecord"
      entry_traces[2]['Flavor'].must_equal "mysql"
      entry_traces[2]['Query'].gsub!(/\d\d\d\d-\d\d-\d\d \d\d:\d\d:\d\d/, 'the_date')
      entry_traces[2]['Query'].must_equal "INSERT INTO `widgets` (`name`, `description`, `created_at`, `updated_at`) VALUES ('blah', 'This is an amazing widget.', 'the_date', 'the_date')"
      entry_traces[2]['Name'].must_equal Rails.version < '5.2.0' ? "SQL" : "Widget Create"
      entry_traces[2].key?('Backtrace').must_equal false
      entry_traces[2].key?('QueryArgs').must_equal Rails.version < '5.2.0' ? true : false

      entry_traces[3]['Layer'].must_equal "activerecord"
      entry_traces[3]['Flavor'].must_equal "mysql"
      entry_traces[3]['Query'].must_equal "SELECT  `widgets`.* FROM `widgets` WHERE `widgets`.`name` = 'blah' ORDER BY `widgets`.`id` ASC LIMIT 1"
      entry_traces[3]['Name'].must_equal "Widget Load"
      entry_traces[3].key?('Backtrace').must_equal false
      entry_traces[3].key?('QueryArgs').must_equal Rails.version < '5.2.0' ? true : false

      entry_traces[4]['Layer'].must_equal "activerecord"
      entry_traces[4]['Flavor'].must_equal "mysql"
      entry_traces[4]['Query'].gsub!(/\d+/, 'ID')
      entry_traces[4]['Query'].must_equal "DELETE FROM `widgets` WHERE `widgets`.`id` = ID"
      entry_traces[4]['Name'].must_equal Rails.version < '5.2.0' ? "SQL" : "Widget Destroy"
      entry_traces[4].key?('Backtrace').must_equal false
      entry_traces[4].key?('QueryArgs').must_equal Rails.version < '5.2.0' ? true : false

      # Validate the existence of the response header
      r.header.key?('X-Trace').must_equal true
      r.header['X-Trace'].must_equal traces[12]['X-Trace']
    end

    # Different behavior in Rails >= 5.2.0
    # https://github.com/rails/rails/pull/30619
    it "should trace rails mysql2 db calls with sanitize sql" do
      # Skip for JRuby since the java instrumentation
      # handles DB instrumentation for JRuby
      skip if defined?(JRUBY_VERSION) || ENV['DBTYPE'] != 'mysql2'

      AppOpticsAPM::Config[:sanitize_sql] = true

      uri = URI.parse('http://127.0.0.1:8140/hello/db')
      r = Net::HTTP.get_response(uri)

      traces = get_all_traces
      traces.count.must_equal 13
      valid_edges?(traces).must_equal true
      validate_outer_layers(traces, 'rack')

      entry_traces = traces.select { |tr| tr['Label'] == 'entry' }
      entry_traces.count.must_equal 6

      exit_traces = traces.select { |tr| tr['Label'] == 'exit' }
      exit_traces.count.must_equal 6

      entry_traces[2]['Layer'].must_equal "activerecord"
      entry_traces[2]['Flavor'].must_equal "mysql"
      entry_traces[2]['Query'].must_equal "INSERT INTO `widgets` (`name`, `description`, `created_at`, `updated_at`) VALUES (?, ?, ?, ?)"
      entry_traces[2]['Name'].must_equal Rails.version < '5.2.0' ? "SQL" : "Widget Create"
      entry_traces[2].key?('Backtrace').must_equal false
      entry_traces[2].key?('QueryArgs').must_equal false

      entry_traces[3]['Layer'].must_equal "activerecord"
      entry_traces[3]['Flavor'].must_equal "mysql"
      entry_traces[3]['Query'].must_equal "SELECT  `widgets`.* FROM `widgets` WHERE `widgets`.`name` = ? ORDER BY `widgets`.`id` ASC LIMIT ?"
      entry_traces[3]['Name'].must_equal "Widget Load"
      entry_traces[3].key?('Backtrace').must_equal false
      entry_traces[3].key?('QueryArgs').must_equal false

      entry_traces[4]['Layer'].must_equal "activerecord"
      entry_traces[4]['Flavor'].must_equal "mysql"
      entry_traces[4]['Query'].must_equal "DELETE FROM `widgets` WHERE `widgets`.`id` = ?"
      entry_traces[4]['Name'].must_equal Rails.version < '5.2.0' ? "SQL" : "Widget Destroy"
      entry_traces[4].key?('Backtrace').must_equal false
      entry_traces[4].key?('QueryArgs').must_equal false

      # Validate the existence of the response header
      r.header.key?('X-Trace').must_equal true
      r.header['X-Trace'].must_equal traces[12]['X-Trace']
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

    it "should collect backtraces when true" do
      AppOpticsAPM::Config[:action_controller][:collect_backtraces] = true

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
      traces[2].key?('Backtrace').must_equal true

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

    it "should NOT collect backtraces when false" do
      AppOpticsAPM::Config[:action_controller][:collect_backtraces] = false

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
      traces[2].key?('Backtrace').must_equal false

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

    it 'should log one exception and create unbroken traces when there is an exception' do
      AppOpticsAPM::Config[:report_rescued_errors] = true
      uri = URI.parse('http://127.0.0.1:8140/hello/error')
      r = Net::HTTP.get_response(uri)

      traces = get_all_traces

      traces.select{ |trace| trace['Label'] == 'error' }.count.must_equal 1
      traces.select{ |trace| trace['Label'] == 'entry' }.count.must_equal 2
      traces.select{ |trace| trace['Label'] == 'exit'  }.count.must_equal 2
    end

    # TODO: figure out how to test this, when does this happen?
    it 'should only log one exception, when it gets raised' do
      skip
    end

    require_relative "rails_shared_tests"
    require_relative "rails_crud_test"
  end
end
