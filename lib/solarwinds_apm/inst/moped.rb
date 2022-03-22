# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'json'

module SolarWindsAPM
  module Inst
    ##
    # Moped
    #
    module Moped
      FLAVOR = :mongodb

      # Moped::Database
      DB_OPS         = [:command, :drop].freeze

      # Moped::Indexes
      INDEX_OPS      = [:create, :drop].freeze

      # Moped::Query
      QUERY_OPS      = [:count, :sort, :limit, :distinct, :update, :update_all, :upsert,
                        :explain, :modify, :remove, :remove_all].freeze

      # Moped::Collection
      COLLECTION_OPS = [:drop, :find, :indexes, :insert, :aggregate].freeze

      ##
      # remote_host
      #
      # This utility method converts the server into a host:port
      # pair for reporting
      #
      def remote_host(server)
        if ::Moped::VERSION < '2.0.0'
          server
        else
          "#{server.address.host}:#{server.address.port}"
        end
      end
    end

    ##
    # MopedDatabase
    #
    module MopedDatabase
      include SolarWindsAPM::Inst::Moped

      def self.included(klass)
        SolarWindsAPM::Inst::Moped::DB_OPS.each do |m|
          SolarWindsAPM::Util.method_alias(klass, m)
        end
      end

      def extract_trace_details(op)
        report_kvs = {}
        report_kvs[:Flavor] = SolarWindsAPM::Inst::Moped::FLAVOR
        # FIXME: We're only grabbing the first of potentially multiple servers here
        report_kvs[:RemoteHost] = remote_host(session.cluster.seeds.first)
        report_kvs[:Database] = name
        report_kvs[:QueryOp] = op.to_s
        report_kvs[:Backtrace] = SolarWindsAPM::API.backtrace if SolarWindsAPM::Config[:moped][:collect_backtraces]
      rescue StandardError => e
        SolarWindsAPM.logger.debug "[solarwinds_apm/debug] #{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}"
      ensure
        return report_kvs
      end

      def command_with_sw_apm(command)
        if SolarWindsAPM.tracing? && !SolarWindsAPM.layer_op && command.key?(:mapreduce)
          begin
            report_kvs = extract_trace_details(:map_reduce)
            report_kvs[:Map_Function] = command[:map]
            report_kvs[:Reduce_Function] = command[:reduce]
          rescue => e
            SolarWindsAPM.logger.debug "[solarwinds_apm/debug] #{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}"
          end

          SolarWindsAPM::SDK.trace(:mongo, kvs: report_kvs) do
            command_without_sw_apm(command)
          end
        else
          command_without_sw_apm(command)
        end
      end

      def drop_with_sw_apm
        return drop_without_sw_apm unless SolarWindsAPM.tracing?

        report_kvs = extract_trace_details(:drop_database)

        SolarWindsAPM::SDK.trace(:mongo, kvs: report_kvs) do
          drop_without_sw_apm
        end
      end
    end

    ##
    # MopedIndexes
    #
    module MopedIndexes
      include SolarWindsAPM::Inst::Moped

      def self.included(klass)
        SolarWindsAPM::Inst::Moped::INDEX_OPS.each do |m|
          SolarWindsAPM::Util.method_alias(klass, m)
        end
      end

      def extract_trace_details(op)
        report_kvs = {}
        report_kvs[:Flavor] = SolarWindsAPM::Inst::Moped::FLAVOR

        # FIXME: We're only grabbing the first of potentially multiple servers here
        first = database.session.cluster.seeds.first
        if ::Moped::VERSION < '2.0.0'
          report_kvs[:RemoteHost] = first
        else
          report_kvs[:RemoteHost] = "#{first.address.host}:#{first.address.port}"
        end
        report_kvs[:Database] = database.name
        report_kvs[:QueryOp] = op.to_s
        report_kvs[:Backtrace] = SolarWindsAPM::API.backtrace if SolarWindsAPM::Config[:moped][:collect_backtraces]
      rescue StandardError => e
        SolarWindsAPM.logger.debug "[solarwinds_apm/debug] #{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}"
      ensure
        return report_kvs
      end

      def create_with_sw_apm(key, options = {})
        return create_without_sw_apm(key, options) unless SolarWindsAPM.tracing?

        begin
          # We report :create_index here to be consistent
          # with other mongo implementations
          report_kvs = extract_trace_details(:create_index)
          report_kvs[:Key] = key.to_json
          report_kvs[:Options] = options.to_json
        rescue StandardError => e
          SolarWindsAPM.logger.debug "[solarwinds_apm/debug] #{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}"
        end

        SolarWindsAPM::API.trace(:mongo, kvs: report_kvs, protect_op: :create_index) do
          create_without_sw_apm(key, options = {})
        end
      end

      def drop_with_sw_apm(key = nil)
        return drop_without_sw_apm(key) unless SolarWindsAPM.tracing?

        begin
          # We report :drop_indexes here to be consistent
          # with other mongo implementations
          report_kvs = extract_trace_details(:drop_indexes)
          report_kvs[:Key] = key.nil? ? :all : key.to_json
        rescue StandardError => e
          SolarWindsAPM.logger.debug "[solarwinds_apm/debug] #{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}"
        end

        SolarWindsAPM::SDK.trace(:mongo, kvs: report_kvs) do
          drop_without_sw_apm(key)
        end
      end
    end

    ##
    # MopedQuery
    #
    module MopedQuery
      include SolarWindsAPM::Inst::Moped

      def self.included(klass)
        SolarWindsAPM::Inst::Moped::QUERY_OPS.each do |m|
          SolarWindsAPM::Util.method_alias(klass, m)
        end
      end

      def extract_trace_details(op)
        report_kvs = {}
        report_kvs[:Flavor] = SolarWindsAPM::Inst::Moped::FLAVOR
        # FIXME: We're only grabbing the first of potentially multiple servers here
        first = collection.database.session.cluster.seeds.first
        report_kvs[:RemoteHost] = remote_host(first)
        report_kvs[:Database] = collection.database.name
        report_kvs[:Collection] = collection.name
        report_kvs[:QueryOp] = op.to_s
        report_kvs[:Backtrace] = SolarWindsAPM::API.backtrace if SolarWindsAPM::Config[:moped][:collect_backtraces]
      rescue StandardError => e
        SolarWindsAPM.logger.debug "[solarwinds_apm/debug] #{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}"
      ensure
        return report_kvs
      end

      def count_with_sw_apm
        return count_without_sw_apm unless SolarWindsAPM.tracing?

        begin
          report_kvs = extract_trace_details(:count)
          report_kvs[:Query] = selector.empty? ? :all : selector.to_json
        rescue StandardError => e
          SolarWindsAPM.logger.debug "[solarwinds_apm/debug] #{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}"
        end

        SolarWindsAPM::SDK.trace(:mongo, kvs: report_kvs) do
          count_without_sw_apm
        end
      end

      def sort_with_sw_apm(sort)
        return sort_without_sw_apm(sort) unless SolarWindsAPM.tracing?

        begin
          report_kvs = extract_trace_details(:sort)
          report_kvs[:Query] = selector.empty? ? :all : selector.to_json
          report_kvs[:Order] = sort.to_s
        rescue StandardError => e
          SolarWindsAPM.logger.debug "[solarwinds_apm/debug] #{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}"
        end

        SolarWindsAPM::SDK.trace(:mongo, kvs: report_kvs) do
          sort_without_sw_apm(sort)
        end
      end

      def limit_with_sw_apm(limit)
        if SolarWindsAPM.tracing? && !SolarWindsAPM.tracing_layer_op?(:explain)
          begin
            report_kvs = extract_trace_details(:limit)
            report_kvs[:Query] = selector.empty? ? :all : selector.to_json
            report_kvs[:Limit] = limit.to_s
          rescue StandardError => e
            SolarWindsAPM.logger.debug "[solarwinds_apm/debug] #{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}"
          end

          SolarWindsAPM::SDK.trace(:mongo, kvs: report_kvs) do
            limit_without_sw_apm(limit)
          end
        else
          limit_without_sw_apm(limit)
        end
      end

      def distinct_with_sw_apm(key)
        return distinct_without_sw_apm(key) unless SolarWindsAPM.tracing?

        begin
          report_kvs = extract_trace_details(:distinct)
          report_kvs[:Query] = selector.empty? ? :all : selector.to_json
          report_kvs[:Key] = key.to_s
        rescue StandardError => e
          SolarWindsAPM.logger.debug "[solarwinds_apm/debug] #{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}"
        end

        SolarWindsAPM::SDK.trace(:mongo, kvs: report_kvs) do
          distinct_without_sw_apm(key)
        end
      end

      def update_with_sw_apm(change, flags = nil)
        if SolarWindsAPM.tracing? && !SolarWindsAPM.tracing_layer_op?(:update_all) && !SolarWindsAPM.tracing_layer_op?(:upsert)
          begin
            report_kvs = extract_trace_details(:update)
            report_kvs[:Flags] = flags.to_s if flags
            report_kvs[:Update_Document] = change.to_json
          rescue StandardError => e
            SolarWindsAPM.logger.debug "[solarwinds_apm/debug] #{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}"
          end

          SolarWindsAPM::SDK.trace(:mongo, kvs: report_kvs) do
            update_without_sw_apm(change, flags)
          end
        else
          update_without_sw_apm(change, flags)
        end
      end

      def update_all_with_sw_apm(change)
        return update_all_without_sw_apm(change) unless SolarWindsAPM.tracing?

        begin
          report_kvs = extract_trace_details(:update_all)
          report_kvs[:Update_Document] = change.to_json
        rescue StandardError => e
          SolarWindsAPM.logger.debug "[solarwinds_apm/debug] #{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}"
        end

        SolarWindsAPM::SDK.trace(:mongo, kvs: report_kvs, protect_op: :update_all) do
          update_all_without_sw_apm(change)
        end
      end

      def upsert_with_sw_apm(change)
        return upsert_without_sw_apm(change) unless SolarWindsAPM.tracing?

        begin
          report_kvs = extract_trace_details(:upsert)
          report_kvs[:Query] = selector.to_json
          report_kvs[:Update_Document] = change.to_json
        rescue StandardError => e
          SolarWindsAPM.logger.debug "[solarwinds_apm/debug] #{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}"
        end

        SolarWindsAPM::SDK.trace(:mongo, kvs: report_kvs, protect_op: :upsert) do
          upsert_without_sw_apm(change)
        end
      end

      def explain_with_sw_apm
        return explain_without_sw_apm unless SolarWindsAPM.tracing?

        begin
          report_kvs = extract_trace_details(:explain)
          report_kvs[:Query] = selector.empty? ? :all : selector.to_json
        rescue StandardError => e
          SolarWindsAPM.logger.debug "[solarwinds_apm/debug] #{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}"
        end

        SolarWindsAPM::SDK.trace(:mongo, kvs: report_kvs, protect_op: :explain) do
          explain_without_sw_apm
        end
      end

      def modify_with_sw_apm(change, options = {})
        return modify_without_sw_apm(change, options) unless SolarWindsAPM.tracing?

        begin
          report_kvs = extract_trace_details(:modify)
          report_kvs[:Update_Document] = selector.empty? ? :all : selector.to_json
          report_kvs[:Change] = change.to_json
          report_kvs[:Options] = options.to_json
        rescue StandardError => e
          SolarWindsAPM.logger.debug "[solarwinds_apm/debug] #{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}"
        end

        SolarWindsAPM::SDK.trace(:mongo, kvs: report_kvs) do
          modify_without_sw_apm(change, options)
        end
      end

      def remove_with_sw_apm
        return remove_without_sw_apm unless SolarWindsAPM.tracing?

        begin
          report_kvs = extract_trace_details(:remove)
          report_kvs[:Query] = selector.to_json
        rescue StandardError => e
          SolarWindsAPM.logger.debug "[solarwinds_apm/debug] #{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}"
        end

        SolarWindsAPM::SDK.trace(:mongo, kvs: report_kvs) do
          remove_without_sw_apm
        end
      end

      def remove_all_with_sw_apm
        return remove_all_without_sw_apm unless SolarWindsAPM.tracing?

        begin
          report_kvs = extract_trace_details(:remove_all)
          report_kvs[:Query] = selector.to_json
        rescue StandardError => e
          SolarWindsAPM.logger.debug "[solarwinds_apm/debug] #{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}"
        end

        SolarWindsAPM::SDK.trace(:mongo, kvs: report_kvs) do
          remove_all_without_sw_apm
        end
      end
    end

    ##
    # MopedCollection
    #
    module MopedCollection
      include SolarWindsAPM::Inst::Moped

      def self.included(klass)
        SolarWindsAPM::Inst::Moped::COLLECTION_OPS.each do |m|
          SolarWindsAPM::Util.method_alias(klass, m)
        end
      end

      def extract_trace_details(op)
        report_kvs = {}
        report_kvs[:Flavor] = SolarWindsAPM::Inst::Moped::FLAVOR
        # FIXME: We're only grabbing the first of potentially multiple servers here
        report_kvs[:RemoteHost] = remote_host(database.session.cluster.seeds.first)
        report_kvs[:Database] = database.name
        report_kvs[:Collection] = name
        report_kvs[:QueryOp] = op.to_s
        report_kvs[:Backtrace] = SolarWindsAPM::API.backtrace if SolarWindsAPM::Config[:moped][:collect_backtraces]
      rescue StandardError => e
        SolarWindsAPM.logger.debug "[solarwinds_apm/debug] #{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}"
      ensure
        return report_kvs
      end

      def drop_with_sw_apm
        return drop_without_sw_apm unless SolarWindsAPM.tracing?

        # We report :drop_collection here to be consistent
        # with other mongo implementations
        report_kvs = extract_trace_details(:drop_collection)

        SolarWindsAPM::SDK.trace(:mongo, kvs: report_kvs) do
          drop_without_sw_apm
        end
      end

      def find_with_sw_apm(selector = {})
        return find_without_sw_apm(selector) unless SolarWindsAPM.tracing?

        begin
          report_kvs = extract_trace_details(:find)
          report_kvs[:Query] = selector.empty? ? 'all' : selector.to_json
        rescue StandardError => e
          SolarWindsAPM.logger.debug "[solarwinds_apm/debug] #{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}"
        end

        SolarWindsAPM::SDK.trace(:mongo, kvs: report_kvs) do
          find_without_sw_apm(selector)
        end
      end

      def indexes_with_sw_apm
        return indexes_without_sw_apm unless SolarWindsAPM.tracing?

        report_kvs = extract_trace_details(:indexes)

        SolarWindsAPM::SDK.trace(:mongo, kvs: report_kvs) do
          indexes_without_sw_apm
        end
      end

      def insert_with_sw_apm(documents, flags = nil)
        if SolarWindsAPM.tracing? && !SolarWindsAPM.tracing_layer_op?(:create_index)
          report_kvs = extract_trace_details(:insert)

          SolarWindsAPM::SDK.trace(:mongo, kvs: report_kvs) do
            insert_without_sw_apm(documents, flags)
          end
        else
          insert_without_sw_apm(documents, flags)
        end
      end

      def aggregate_with_sw_apm(*pipeline)
        return aggregate_without_sw_apm(*pipeline) unless SolarWindsAPM.tracing?

        report_kvs = extract_trace_details(:aggregate)
        report_kvs[:Query] = pipeline

        SolarWindsAPM::SDK.trace(:mongo, kvs: report_kvs) do
          aggregate_without_sw_apm(pipeline)
        end
      end
    end
  end
end

if defined?(Moped) && SolarWindsAPM::Config[:moped][:enabled]
  SolarWindsAPM.logger.info '[solarwinds_apm/loading] Instrumenting moped' if SolarWindsAPM::Config[:verbose]
  SolarWindsAPM::Util.send_include(Moped::Database,   SolarWindsAPM::Inst::MopedDatabase)
  SolarWindsAPM::Util.send_include(Moped::Collection, SolarWindsAPM::Inst::MopedCollection)
  SolarWindsAPM::Util.send_include(Moped::Query,      SolarWindsAPM::Inst::MopedQuery)
  SolarWindsAPM::Util.send_include(Moped::Indexes,    SolarWindsAPM::Inst::MopedIndexes)
end
