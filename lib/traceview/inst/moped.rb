# Copyright (c) 2013 AppNeta, Inc.
# All rights reserved.

require 'json'

module TraceView
  module Inst
    module Moped
      FLAVOR = 'mongodb'

      # Moped::Database
      DB_OPS         = [:command, :drop]

      # Moped::Indexes
      INDEX_OPS      = [:create, :drop]

      # Moped::Query
      QUERY_OPS      = [:count, :sort, :limit, :distinct, :update, :update_all, :upsert,
                        :explain, :modify, :remove, :remove_all]

      # Moped::Collection
      COLLECTION_OPS = [:drop, :find, :indexes, :insert, :aggregate]
    end
  end
end

if defined?(::Moped) && TraceView::Config[:moped][:enabled]
  TraceView.logger.info '[traceview/loading] Instrumenting moped' if TraceView::Config[:verbose]

  if defined?(::Moped::Database)
    module ::Moped
      class Database
        include TraceView::Inst::Moped

        def extract_trace_details(op)
          report_kvs = {}
          begin
            report_kvs[:Flavor] = TraceView::Inst::Moped::FLAVOR
            # FIXME: We're only grabbing the first of potentially multiple servers here
            first = session.cluster.seeds.first
            if ::Moped::VERSION < '2.0.0'
              report_kvs[:RemoteHost] = first
            else
              report_kvs[:RemoteHost] = "#{first.address.host}:#{first.address.port}"
            end
            report_kvs[:Database] = name
            report_kvs[:QueryOp] = op.to_s
            report_kvs[:Backtrace] = TraceView::API.backtrace if TraceView::Config[:moped][:collect_backtraces]
          rescue StandardError => e
            TraceView.logger.debug "[traceview/debug] #{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}" if TraceView::Config[:verbose]
          end
          report_kvs
        end

        def command_with_traceview(command)
          if TraceView.tracing? && !TraceView.layer_op && command.key?(:mapreduce)
            begin
              report_kvs = extract_trace_details(:map_reduce)
              report_kvs[:Map_Function] = command[:map]
              report_kvs[:Reduce_Function] = command[:reduce]
            rescue => e
              TraceView.logger.debug "[traceview/debug] #{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}" if TraceView::Config[:verbose]
            end

            TraceView::API.trace('mongo', report_kvs) do
              command_without_traceview(command)
            end
          else
            command_without_traceview(command)
          end
        end

        def drop_with_traceview
          return drop_without_traceview unless TraceView.tracing?

          report_kvs = extract_trace_details(:drop_database)

          TraceView::API.trace('mongo', report_kvs) do
            drop_without_traceview
          end
        end

        TraceView::Inst::Moped::DB_OPS.each do |m|
          if method_defined?(m)
            class_eval "alias #{m}_without_traceview #{m}"
            class_eval "alias #{m} #{m}_with_traceview"
          else TraceView.logger.warn "[traceview/loading] Couldn't properly instrument moped (#{m}).  Partial traces may occur."
          end
        end
      end
    end
  end

  if defined?(::Moped::Indexes)
    module ::Moped
      class Indexes
        include TraceView::Inst::Moped

        def extract_trace_details(op)
          report_kvs = {}
          begin
            report_kvs[:Flavor] = TraceView::Inst::Moped::FLAVOR

            # FIXME: We're only grabbing the first of potentially multiple servers here
            first = database.session.cluster.seeds.first
            if ::Moped::VERSION < '2.0.0'
              report_kvs[:RemoteHost] = first
            else
              report_kvs[:RemoteHost] = "#{first.address.host}:#{first.address.port}"
            end
            report_kvs[:Database] = database.name
            report_kvs[:QueryOp] = op.to_s
            report_kvs[:Backtrace] = TraceView::API.backtrace if TraceView::Config[:moped][:collect_backtraces]
          rescue StandardError => e
            TraceView.logger.debug "[traceview/debug] #{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}" if TraceView::Config[:verbose]
          end
          report_kvs
        end

        def create_with_traceview(key, options = {})
          return create_without_traceview(key, options) unless TraceView.tracing?

          begin
            # We report :create_index here to be consistent
            # with other mongo implementations
            report_kvs = extract_trace_details(:create_index)
            report_kvs[:Key] = key.to_json
            report_kvs[:Options] = options.to_json
          rescue StandardError => e
            TraceView.logger.debug "[traceview/debug] #{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}" if TraceView::Config[:verbose]
          end

          TraceView::API.trace('mongo', report_kvs, :create_index) do
            create_without_traceview(key, options = {})
          end
        end

        def drop_with_traceview(key = nil)
          return drop_without_traceview(key) unless TraceView.tracing?

          begin
            # We report :drop_indexes here to be consistent
            # with other mongo implementations
            report_kvs = extract_trace_details(:drop_indexes)
            report_kvs[:Key] = key.nil? ? 'all' : key.to_json
          rescue StandardError => e
            TraceView.logger.debug "[traceview/debug] #{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}" if TraceView::Config[:verbose]
          end

          TraceView::API.trace('mongo', report_kvs) do
            drop_without_traceview(key = nil)
          end
        end

        TraceView::Inst::Moped::INDEX_OPS.each do |m|
          if method_defined?(m)
            class_eval "alias #{m}_without_traceview #{m}"
            class_eval "alias #{m} #{m}_with_traceview"
          else TraceView.logger.warn "[traceview/loading] Couldn't properly instrument moped (#{m}).  Partial traces may occur."
          end
        end
      end
    end
  end

  if defined?(::Moped::Query)
    module ::Moped
      class Query
        include TraceView::Inst::Moped

        def extract_trace_details(op)
          report_kvs = {}
          begin
            report_kvs[:Flavor] = TraceView::Inst::Moped::FLAVOR
            # FIXME: We're only grabbing the first of potentially multiple servers here
            first = collection.database.session.cluster.seeds.first
            if ::Moped::VERSION < '2.0.0'
              report_kvs[:RemoteHost] = first
            else
              report_kvs[:RemoteHost] = "#{first.address.host}:#{first.address.port}"
            end
            report_kvs[:Database] = collection.database.name
            report_kvs[:Collection] = collection.name
            report_kvs[:QueryOp] = op.to_s
            report_kvs[:Backtrace] = TraceView::API.backtrace if TraceView::Config[:moped][:collect_backtraces]
          rescue StandardError => e
            TraceView.logger.debug "[traceview/debug] #{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}" if TraceView::Config[:verbose]
          end
          report_kvs
        end

        def count_with_traceview
          return count_without_traceview unless TraceView.tracing?

          begin
            report_kvs = extract_trace_details(:count)
            report_kvs[:Query] = selector.empty? ? 'all' : selector.to_json
          rescue StandardError => e
            TraceView.logger.debug "[traceview/debug] #{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}" if TraceView::Config[:verbose]
          end

          TraceView::API.trace('mongo', report_kvs) do
            count_without_traceview
          end
        end

        def sort_with_traceview(sort)
          return sort_without_traceview(sort) unless TraceView.tracing?

          begin
            report_kvs = extract_trace_details(:sort)
            report_kvs[:Query] = selector.empty? ? 'all' : selector.to_json
            report_kvs[:Order] = sort.to_s
          rescue StandardError => e
            TraceView.logger.debug "[traceview/debug] #{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}" if TraceView::Config[:verbose]
          end

          TraceView::API.trace('mongo', report_kvs) do
            sort_without_traceview(sort)
          end
        end

        def limit_with_traceview(limit)
          if TraceView.tracing? && !TraceView.tracing_layer_op?(:explain)
            begin
              report_kvs = extract_trace_details(:limit)
              report_kvs[:Query] = selector.empty? ? 'all' : selector.to_json
              report_kvs[:Limit] = limit.to_s
            rescue StandardError => e
              TraceView.logger.debug "[traceview/debug] #{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}" if TraceView::Config[:verbose]
            end

            TraceView::API.trace('mongo', report_kvs) do
              limit_without_traceview(limit)
            end
          else
            limit_without_traceview(limit)
          end
        end

        def distinct_with_traceview(key)
          return distinct_without_traceview(key) unless TraceView.tracing?

          begin
            report_kvs = extract_trace_details(:distinct)
            report_kvs[:Query] = selector.empty? ? 'all' : selector.to_json
            report_kvs[:Key] = key.to_s
          rescue StandardError => e
            TraceView.logger.debug "[traceview/debug] #{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}" if TraceView::Config[:verbose]
          end

          TraceView::API.trace('mongo', report_kvs) do
            distinct_without_traceview(key)
          end
        end

        def update_with_traceview(change, flags = nil)
          if TraceView.tracing? && !TraceView.tracing_layer_op?([:update_all, :upsert])
            begin
              report_kvs = extract_trace_details(:update)
              report_kvs[:Flags] = flags.to_s if flags
              report_kvs[:Update_Document] = change.to_json
            rescue StandardError => e
              TraceView.logger.debug "[traceview/debug] #{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}" if TraceView::Config[:verbose]
            end

            TraceView::API.trace('mongo', report_kvs) do
              update_without_traceview(change, flags)
            end
          else
            update_without_traceview(change, flags)
          end
        end

        def update_all_with_traceview(change)
          return update_all_without_traceview(change) unless TraceView.tracing?

          begin
            report_kvs = extract_trace_details(:update_all)
            report_kvs[:Update_Document] = change.to_json
          rescue StandardError => e
            TraceView.logger.debug "[traceview/debug] #{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}" if TraceView::Config[:verbose]
          end

          TraceView::API.trace('mongo', report_kvs, :update_all) do
            update_all_without_traceview(change)
          end
        end

        def upsert_with_traceview(change)
          return upsert_without_traceview(change) unless TraceView.tracing?

          begin
            report_kvs = extract_trace_details(:upsert)
            report_kvs[:Query] = selector.to_json
            report_kvs[:Update_Document] = change.to_json
          rescue StandardError => e
            TraceView.logger.debug "[traceview/debug] #{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}" if TraceView::Config[:verbose]
          end

          TraceView::API.trace('mongo', report_kvs, :upsert) do
            upsert_without_traceview(change)
          end
        end

        def explain_with_traceview
          return explain_without_traceview unless TraceView.tracing?

          begin
            report_kvs = extract_trace_details(:explain)
            report_kvs[:Query] = selector.empty? ? 'all' : selector.to_json
          rescue StandardError => e
            TraceView.logger.debug "[traceview/debug] #{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}" if TraceView::Config[:verbose]
          end

          TraceView::API.trace('mongo', report_kvs, :explain) do
            explain_without_traceview
          end
        end

        def modify_with_traceview(change, options = {})
          return modify_without_traceview(change, options) unless TraceView.tracing?

          begin
            report_kvs = extract_trace_details(:modify)
            report_kvs[:Update_Document] = selector.empty? ? 'all' : selector.to_json
            report_kvs[:Change] = change.to_json
            report_kvs[:Options] = options.to_json
          rescue StandardError => e
            TraceView.logger.debug "[traceview/debug] #{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}" if TraceView::Config[:verbose]
          end

          TraceView::API.trace('mongo', report_kvs) do
            modify_without_traceview(change, options)
          end
        end

        def remove_with_traceview
          return remove_without_traceview unless TraceView.tracing?

          begin
            report_kvs = extract_trace_details(:remove)
            report_kvs[:Query] = selector.to_json
          rescue StandardError => e
            TraceView.logger.debug "[traceview/debug] #{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}" if TraceView::Config[:verbose]
          end

          TraceView::API.trace('mongo', report_kvs) do
            remove_without_traceview
          end
        end

        def remove_all_with_traceview
          return remove_all_without_traceview unless TraceView.tracing?

          begin
            report_kvs = extract_trace_details(:remove_all)
            report_kvs[:Query] = selector.to_json
          rescue StandardError => e
            TraceView.logger.debug "[traceview/debug] #{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}" if TraceView::Config[:verbose]
          end

          TraceView::API.trace('mongo', report_kvs) do
            remove_all_without_traceview
          end
        end

        TraceView::Inst::Moped::QUERY_OPS.each do |m|
          if method_defined?(m)
            class_eval "alias #{m}_without_traceview #{m}"
            class_eval "alias #{m} #{m}_with_traceview"
          else TraceView.logger.warn "[traceview/loading] Couldn't properly instrument moped (#{m}).  Partial traces may occur."
          end
        end
      end
    end
  end # ::Moped::Query

  if defined?(::Moped::Collection)
    module ::Moped
      class Collection
        include TraceView::Inst::Moped

        def extract_trace_details(op)
          report_kvs = {}
          begin
            report_kvs[:Flavor] = TraceView::Inst::Moped::FLAVOR
            # FIXME: We're only grabbing the first of potentially multiple servers here
            first = database.session.cluster.seeds.first
            if ::Moped::VERSION < '2.0.0'
              report_kvs[:RemoteHost] = first
            else
              report_kvs[:RemoteHost] = "#{first.address.host}:#{first.address.port}"
            end
            report_kvs[:Database] = database.name
            report_kvs[:Collection] = name
            report_kvs[:QueryOp] = op.to_s
            report_kvs[:Backtrace] = TraceView::API.backtrace if TraceView::Config[:moped][:collect_backtraces]
          rescue StandardError => e
            TraceView.logger.debug "[traceview/debug] #{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}" if TraceView::Config[:verbose]
          end
          report_kvs
        end

        def drop_with_traceview
          return drop_without_traceview unless TraceView.tracing?

          # We report :drop_collection here to be consistent
          # with other mongo implementations
          report_kvs = extract_trace_details(:drop_collection)

          TraceView::API.trace('mongo', report_kvs) do
            drop_without_traceview
          end
        end

        def find_with_traceview(selector = {})
          return find_without_traceview(selector) unless TraceView.tracing?

          begin
            report_kvs = extract_trace_details(:find)
            report_kvs[:Query] = selector.empty? ? 'all' : selector.to_json
          rescue StandardError => e
            TraceView.logger.debug "[traceview/debug] #{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}" if TraceView::Config[:verbose]
          end

          TraceView::API.trace('mongo', report_kvs) do
            find_without_traceview(selector)
          end
        end

        def indexes_with_traceview
          return indexes_without_traceview unless TraceView.tracing?

          report_kvs = extract_trace_details(:indexes)

          TraceView::API.trace('mongo', report_kvs) do
            indexes_without_traceview
          end
        end

        def insert_with_traceview(documents, flags = nil)
          if TraceView.tracing? && !TraceView.tracing_layer_op?(:create_index)
            report_kvs = extract_trace_details(:insert)

            TraceView::API.trace('mongo', report_kvs) do
              insert_without_traceview(documents, flags)
            end
          else
            insert_without_traceview(documents, flags)
          end
        end

        def aggregate_with_traceview(*pipeline)
          return aggregate_without_traceview(*pipeline) unless TraceView.tracing?

          report_kvs = extract_trace_details(:aggregate)
          report_kvs[:Query] = pipeline

          TraceView::API.trace('mongo', report_kvs) do
            aggregate_without_traceview(pipeline)
          end
        end

        TraceView::Inst::Moped::COLLECTION_OPS.each do |m|
          if method_defined?(m)
            class_eval "alias #{m}_without_traceview #{m}"
            class_eval "alias #{m} #{m}_with_traceview"
          else TraceView.logger.warn "[traceview/loading] Couldn't properly instrument moped (#{m}).  Partial traces may occur."
          end
        end
      end
    end
  end # ::Moped::Collection
end
