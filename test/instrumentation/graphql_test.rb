# frozen_string_literal: true

#--
# Copyright (c) 2019 SolarWinds, LLC.
# All rights reserved.
#++

require 'minitest_helper'
require 'mocha/minitest'

describe GraphQL::Tracing::AppOpticsTracing do
  module Mutations
    class BaseMutation < GraphQL::Schema::Mutation
      #   null false
    end

    class CreateCompany < Mutations::BaseMutation
      argument :name, String, required: true
      argument :id, Integer, required: true

      field :name, String, null: true
      field :id, Integer, null: false

      def resolve(name:, id:)
        OpenStruct.new(
          id: id,
          name: name
        )
      end
    end
  end

  module Types
    class BaseArgument < GraphQL::Schema::Argument
    end

    class BaseField < GraphQL::Schema::Field
      argument_class Types::BaseArgument
    end

    class BaseObject < GraphQL::Schema::Object
      field_class Types::BaseField
    end

    class MyMutation < GraphQL::Schema::Object
      field :create_company, mutation: Mutations::CreateCompany
    end
  end

  module AppOpticsTest
    class Schema < GraphQL::Schema
      def self.id_from_object(_object = nil, _type = nil, _context = {})
        SecureRandom.uuid
      end

      class Address < GraphQL::Schema::Object
        global_id_field :id
        field :street, String, null: true
        field :number, Integer, null: true
        field :more, Integer, null: true
      end

      class Person < GraphQL::Schema::Object
        global_id_field :id
        field :name, String, null: true
        field :other_name, String, null: true do
          argument :upcase, String, required: false
        end

        def other_name(upcase = false)
          return 'WHO AM I???' if upcase

          'who am i?'
        end
      end

      class Company < GraphQL::Schema::Object
        global_id_field :id
        field :name, String, null: true
        field :address, Schema::Address, null: true
        field :founder, Schema::Person, null: true
        field :owner, Schema::Person, null: true

        def address
          OpenStruct.new(
            id: AppOpticsTest::Schema.id_from_object,
            street: 'MyStreetName',
            number: Random.new.rand(555),
            more: nil
          )
        end

        def founder
          OpenStruct.new(
            id: AppOpticsTest::Schema.id_from_object,
            name: 'Peter Pan'
          )
        end

        def owner
          OpenStruct.new(
            id: AppOpticsTest::Schema.id_from_object,
            name: { a: 1 }
          )
        end
      end
      # rubocop:disable Style/SingleLineMethods
      class MyQuery < GraphQL::Schema::Object
        field :int, Integer, null: false
        def int; 1; end

        field :company, Company, null: true do
          argument :id, ID, required: true
        end

        def company(id:)
          OpenStruct.new(
            id: id,
            name: 'MyName'
          )
        end
      end
      # rubocop:enable Style/SingleLineMethods

      query MyQuery
      mutation Types::MyMutation
      use GraphQL::Tracing::AppOpticsTracing
    end
  end

  # Tests for the graphql gem instrumentation
  before do
    clear_all_traces

    @sanitize_query = AppOpticsAPM::Config[:graphql][:sanitize_query]
    @remove_comments = AppOpticsAPM::Config[:graphql][:remove_comments]
    @enabled = AppOpticsAPM::Config[:graphql][:enabled]
    @transaction_name = AppOpticsAPM::Config[:graphql][:transaction_name]
  end

  after do
    AppOpticsAPM::Config[:graphql][:sanitize_query] = @sanitize_query
    AppOpticsAPM::Config[:graphql][:remove_comments] = @remove_comments
    AppOpticsAPM::Config[:graphql][:enabled] = @enabled
    AppOpticsAPM::Config[:graphql][:transaction_name] = @transaction_name
  end

  it 'traces a simple graphql request' do
    AppOpticsAPM::SDK.start_trace('graphql_test') do
      query = 'query MyQuery { int }'
      AppOpticsTest::Schema.execute(query)
    end

    traces = get_all_traces

    # this also checks the presence of X-Trace
    assert valid_edges?(traces, true), 'failed: edges not valid'

    keys = GraphQL::Tracing::AppOpticsTracing::PREP_KEYS.dup
    traces.each do |tr|
      if tr[:Layer] == 'graphql.prep' && tr[:Label] == 'entry'
        assert tr[:Key], 'failure: no :Key in the KVs in the graphql.prep span'
        keys = keys.delete(tr[:Key])
      end
    end
    # The following applies that all the prep events are used
    # (This may not always be true, it is also not that important, but lets test
    # it so we get alerted when something changes)
    assert_empty keys

    tr_01 = traces[1]
    assert_equal "graphql.prep", tr_01[:Layer]
    assert_equal "entry", tr_01[:Label]
    assert_equal "graphql", tr_01[:Spec]
    assert_equal "query MyQuery { int }", tr_01[:InboundQuery]

    assert_equal "graphql.query.MyQuery", traces.last[:TransactionName]
  end

  # rubocop:disable Lint/AmbiguousBlockAssociation
  it 'traces a more complex graphql request' do
    query = <<-GRAPHQL
        query MyQuery { company(id: "abc") {
          founder {
            name
          }
          owner {
            name
          }
        }}
    GRAPHQL

    AppOpticsAPM::SDK.start_trace('graphql_test') do
      AppOpticsTest::Schema.execute(query)
    end

    traces = get_all_traces
    assert valid_edges?(traces, true), 'failed: edges not valid'

    assert traces.find { |tr| tr[:InboundQuery] == query.gsub(/abc/, '?') }

    assert traces.find { |tr| tr[:Layer] == 'graphql.MyQuery.company' && tr[:Label] == 'entry' }
    assert traces.find { |tr| tr[:Layer] == 'graphql.MyQuery.company' && tr[:Label] == 'exit' }
    assert traces.find { |tr| tr[:Layer] == 'graphql.Company.founder' && tr[:Label] == 'entry' }
    assert traces.find { |tr| tr[:Layer] == 'graphql.Company.founder' && tr[:Label] == 'exit' }
    assert traces.find { |tr| tr[:Layer] == 'graphql.Company.owner' && tr[:Label] == 'entry' }
    assert traces.find { |tr| tr[:Layer] == 'graphql.Company.owner' && tr[:Label] == 'exit' }
  end

  it 'traces a mutation' do
    query = <<-GRAPHQL
      mutation { createCompany (id: 7, name: "the best") {
        name
        id
      }}
    GRAPHQL

    AppOpticsAPM::SDK.start_trace('graphql_test') do
      AppOpticsTest::Schema.execute(query)
    end

    traces = get_all_traces
    assert valid_edges?(traces, true), 'failed: edges not valid'

    assert traces.find { |tr| tr[:Layer] == 'graphql.MyMutation.createCompany' && tr[:Label] == 'entry' }
    assert traces.find { |tr| tr[:Layer] == 'graphql.MyMutation.createCompany' && tr[:Label] == 'exit' }
  end
  # rubocop:enable Lint/AmbiguousBlockAssociation

  it 'adds an error event' do
    AppOpticsAPM::SDK.start_trace('graphql_test') do
      query = 'query MyQuery { doErr }'
      AppOpticsTest::Schema.execute(query)
    end

    traces = get_all_traces
    assert valid_edges?(traces, true), 'failed: edges not valid'

    error_tr = traces.find { |tr| tr[:Label] == 'info' && tr[:Message] }

    assert error_tr, 'failed: No Error event was logged with the trace'
  end

  # the best I can currently provoke are multiple errors during static validation
  # ideally I would like to provoke multiple errors during execution, but those
  # either trigger only one error or get summarized in the response
  it 'add multiple error events' do
    query = <<-GRAPHQL
        query MyQuery { company(id: "abc") {
          founder {
            age
          }
          owner {
            city
          }
        }}
    GRAPHQL

    AppOpticsAPM::SDK.start_trace('graphql_test') do
      AppOpticsTest::Schema.execute(query)

      traces = get_all_traces
      assert valid_edges?(traces, true), 'failed: edges not valid'

      error_tr = traces.find { |tr| tr[:Label] == 'info' && tr[:Message] }

      assert error_tr, 'failed: No Error event was logged with the trace'
      assert_equal 3, error_tr[:Message].split("\n").size, 'failed: There should have been 2 errors logged with the trace'
    end
  end

  describe 'test configs' do
    let(:query) do
      <<-GRAPHQL
        query MyQuery { company(id: "abc") {
          founder {
            # I forgot her name
            name
            otherName(upcase: "yes please")
          }
        }}
      GRAPHQL
    end

    it 'replaces query parameters if sanitize_query is TRUE' do
      AppOpticsAPM::Config[:graphql][:sanitize_query] = true

      AppOpticsAPM::SDK.start_trace('graphql_test') do
        AppOpticsTest::Schema.execute(query)

        traces = get_all_traces
        traces.each do |tr|
          if tr[:InboundQuery]
            refute_match 'abc', tr[:InboundQuery]
            refute_match 'yes please', tr[:InboundQuery]
          end
        end
      end
    end

    it 'does not replace query parameters if sanitize_query is FALSE' do
      AppOpticsAPM::Config[:graphql][:sanitize_query] = false

      AppOpticsAPM::SDK.start_trace('graphql_test') do
        AppOpticsTest::Schema.execute(query)

        traces = get_all_traces
        traces.each do |tr|
          if tr[:InboundQuery]
            assert_match 'abc', tr[:InboundQuery]
            assert_match 'yes please', tr[:InboundQuery]
          end
        end
      end
    end

    it 'removes comments if remove_comment is TRUE' do
      AppOpticsAPM::Config[:graphql][:remove_comments] = true

      AppOpticsAPM::SDK.start_trace('graphql_test') do
        AppOpticsTest::Schema.execute(query)

        traces = get_all_traces
        traces.each do |tr|
          refute_match '#', tr[:InboundQuery] if tr[:InboundQuery]
        end
      end
    end

    it 'does not remove comments if remove_comment is FALSE' do
      AppOpticsAPM::Config[:graphql][:remove_comments] = false

      AppOpticsAPM::SDK.start_trace('graphql_test') do
        AppOpticsTest::Schema.execute(query)

        traces = get_all_traces
        traces.each do |tr|
          assert_match '#', tr[:InboundQuery] if tr[:InboundQuery]
        end
      end
    end

    it 'sets a graphql transaction name if transaction_name is TRUE' do
      AppOpticsAPM::Config[:graphql][:transaction_name] = true
      AppOpticsAPM::SDK.start_trace('graphql_test') do
        AppOpticsTest::Schema.execute(query)
      end

      trace = get_all_traces.last
      assert_equal "graphql.query.MyQuery", trace[:TransactionName]
    end

    it 'does not set a graphql transaction name if transaction_name is FALSE' do
      AppOpticsAPM::Config[:graphql][:transaction_name] = false
      AppOpticsAPM::SDK.start_trace('graphql_test') do
        AppOpticsTest::Schema.execute(query)
      end

      trace = get_all_traces.last
      assert_equal "custom-graphql_test", trace[:TransactionName]
    end

    it 'does not create traces if graphql is not enabled' do
      AppOpticsAPM::Config[:graphql][:enabled] = false
      AppOpticsAPM::SDK.start_trace('graphql_test') do
        AppOpticsTest::Schema.execute(query)
      end
      traces = get_all_traces
      assert_equal 2, traces.size, "failed: It should not have created traces for graphql"
    end

    it 'does not trace if there is no context' do
      AppOpticsTest::Schema.execute(query)
      traces = get_all_traces
      assert_empty traces, 'failed: it should not have created any traces'
    end
  end

  describe 'loading' do
    let :graphql_appoptics do
      File.join(Gem.loaded_specs['graphql'].full_gem_path, 'lib/graphql/tracing/appoptics_tracing.rb')
    end

    before do
      # it does not make sense but this has to be done before, but otherwise it
      # gets stuck with the graphql version of GraphQL::Tracing::AppOpticsTracing
      Kernel.silence_warnings do
        GraphQL::Tracing::AppOpticsTracing::VERSION = Gem::Version.new('0.0.1')
        load 'lib/appoptics_apm/inst/graphql.rb'
      end
    end

    it 'uses the newer version of AppOpticsTracing from the appoptics_apm gem' do
      skip unless File.exist?(graphql_appoptics)
      Kernel.silence_warnings do # silence warning about re-initializing a const
        load graphql_appoptics
        # make the graphql version return an low version number
        @version = GraphQL::Tracing::AppOpticsTracing::VERSION
        GraphQL::Tracing::AppOpticsTracing::VERSION = Gem::Version.new('0.0.1')

        load 'lib/appoptics_apm/inst/graphql.rb'
        assert_match 'lib/appoptics_apm/inst/graphql.rb',
                     GraphQL::Tracing::AppOpticsTracing.new.method(:metadata).source_location[0]
        assert_match 'lib/appoptics_apm/inst/graphql.rb',
                     GraphQL::Tracing::AppOpticsTracing.new.method(:platform_trace).source_location[0]
      end
    end

    it 'uses the newer version of AppOpticsTracing from the graphql gem' do
      skip unless File.exist?(graphql_appoptics)
      Kernel.silence_warnings do # silence warning about re-initializing a const
        load graphql_appoptics
        # make the graphql version return an high version number
        @version = GraphQL::Tracing::AppOpticsTracing::VERSION
        GraphQL::Tracing::AppOpticsTracing::VERSION = Gem::Version.new('999.0.0')
        load 'lib/appoptics_apm/inst/graphql.rb'
        assert_match 'graphql-ruby/lib/graphql/tracing/appoptics_tracing.rb',
                     GraphQL::Tracing::AppOpticsTracing.new.method(:metadata).source_location[0]
        assert_match 'graphql-ruby/lib/graphql/tracing/appoptics_tracing.rb',
                     GraphQL::Tracing::AppOpticsTracing.new.method(:platform_trace).source_location[0]
      end
    end
  end

  it 'does not add plugins twice' do
    GraphQL::Schema.use(GraphQL::Tracing::AppOpticsTracing)
    GraphQL::Schema.use(GraphQL::Tracing::AppOpticsTracing)

    assert_equal GraphQL::Schema.plugins.uniq.size, GraphQL::Schema.plugins.size,
                 'failed: duplicate plugins found'
  end
end
