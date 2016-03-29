# Copyright (c) 2013 AppNeta, Inc.
# All rights reserved.

require 'json'

module TraceView
  module Inst
    module Mongo
      FLAVOR = 'mongodb'

      # Operations for Mongo::DB
      DB_OPS         = [:create_collection, :drop_collection]

      # Operations for Mongo::Cursor
      CURSOR_OPS     = [:count]

      # Operations for Mongo::Collection
      COLL_WRITE_OPS = [:find_and_modify, :insert, :map_reduce, :remove, :rename, :update]
      COLL_QUERY_OPS = [:distinct, :find, :group]
      COLL_INDEX_OPS = [:create_index, :drop_index, :drop_indexes, :ensure_index, :index_information]
    end
  end
end

if defined?(::Mongo) && (Gem.loaded_specs['mongo'].version.to_s < '2.0.0') && TraceView::Config[:mongo][:enabled]
  TraceView.logger.info '[traceview/loading] Instrumenting mongo' if TraceView::Config[:verbose]

  if defined?(::Mongo::DB)
    module ::Mongo
      class DB
        include TraceView::Inst::Mongo

        # Instrument DB operations
        TraceView::Inst::Mongo::DB_OPS.reject { |m| !method_defined?(m) }.each do |m|
          define_method("#{m}_with_traceview") do |*args|
            report_kvs = {}

            begin
              report_kvs[:Flavor] = TraceView::Inst::Mongo::FLAVOR

              report_kvs[:Database] = @name

              # Mongo >= 1.10 uses @client instead of @connection
              # Avoid the nil
              if @connection
                report_kvs[:RemoteHost] = @connection.host
                report_kvs[:RemotePort] = @connection.port
              elsif @client
                report_kvs[:RemoteHost] = @client.host
                report_kvs[:RemotePort] = @client.port
              end

              report_kvs[:QueryOp] = m

              report_kvs[:New_Collection_Name] = args[0] if m == :create_collection
              report_kvs[:Collection] = args[0]          if m == :drop_collection

              report_kvs[:Backtrace] = TraceView::API.backtrace if TraceView::Config[:mongo][:collect_backtraces]
            rescue => e
              TraceView.logger.debug "[traceview/debug] #{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}" if TraceView::Config[:verbose]
            end

            TraceView::API.trace('mongo', report_kvs) do
              send("#{m}_without_traceview", *args)
            end
          end

          class_eval "alias #{m}_without_traceview #{m}"
          class_eval "alias #{m} #{m}_with_traceview"
        end
      end
    end
  end

  if defined?(::Mongo::Cursor)
    module ::Mongo
      class Cursor
        include TraceView::Inst::Mongo

        # Instrument DB cursor operations
        TraceView::Inst::Mongo::CURSOR_OPS.reject { |m| !method_defined?(m) }.each do |m|
          define_method("#{m}_with_traceview") do |*args|
            report_kvs = {}

            begin
              report_kvs[:Flavor] = TraceView::Inst::Mongo::FLAVOR

              report_kvs[:Database] = @db.name
              report_kvs[:RemoteHost] = @connection.host
              report_kvs[:RemotePort] = @connection.port

              report_kvs[:QueryOp] = m
              if m == :count
                unless @selector.empty?
                  report_kvs[:Query] = @selector.to_json
                else
                  report_kvs[:Query] = 'all'
                end
                report_kvs[:Limit] = @limit if @limit != 0
              end
            rescue => e
              TraceView.logger.debug "[traceview/debug] #{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}" if TraceView::Config[:verbose]
            end

            TraceView::API.trace('mongo', report_kvs) do
              send("#{m}_without_traceview", *args)
            end
          end

          class_eval "alias #{m}_without_traceview #{m}"
          class_eval "alias #{m} #{m}_with_traceview"
        end
      end
    end
  end

  if defined?(::Mongo::Collection)
    module ::Mongo
      class Collection
        include TraceView::Inst::Mongo

        def traceview_collect(m, args)
          kvs = {}
          kvs[:Flavor] = TraceView::Inst::Mongo::FLAVOR

          kvs[:Database] = @db.name
          kvs[:RemoteHost] = @db.connection.host
          kvs[:RemotePort] = @db.connection.port
          kvs[:Collection] = @name

          kvs[:Backtrace] = TraceView::API.backtrace if TraceView::Config[:mongo][:collect_backtraces]

          kvs[:QueryOp] = m
          kvs[:Query] = args[0].to_json if args && !args.empty? && args[0].class == Hash
        rescue StandardError => e
          TraceView.logger.debug "[traceview/debug] Exception in traceview_collect KV collection: #{e.inspect}"
        ensure
          return kvs
        end

        # Instrument Collection write operations
        TraceView::Inst::Mongo::COLL_WRITE_OPS.reject { |m| !method_defined?(m) }.each do |m|
          define_method("#{m}_with_traceview") do |*args|
            report_kvs = traceview_collect(m, args)
            args_length = args.length

            begin
              if m == :find_and_modify && args[0] && args[0].key?(:update)
                report_kvs[:Update_Document] = args[0][:update].inspect
              end

              if m == :map_reduce
                report_kvs[:Map_Function]    = args[0]
                report_kvs[:Reduce_Function] = args[1]
                report_kvs[:Limit] = args[2][:limit] if args[2] && args[2].key?(:limit)
              end

              report_kvs[:New_Collection_Name] = args[0] if m == :rename

              if m == :update
                if args_length >= 3
                  report_kvs[:Update_Document] = args[1].to_json
                  report_kvs[:Multi] = args[2][:multi] if args[2] && args[2].key?(:multi)
                end
              end
            rescue => e
              TraceView.logger.debug "[traceview/debug] #{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}" if TraceView::Config[:verbose]
            end

            TraceView::API.trace('mongo', report_kvs) do
              send("#{m}_without_traceview", *args)
            end
          end

          class_eval "alias #{m}_without_traceview #{m}"
          class_eval "alias #{m} #{m}_with_traceview"
        end

        # Instrument Collection query operations
        TraceView::Inst::Mongo::COLL_QUERY_OPS.reject { |m| !method_defined?(m) }.each do |m|
          define_method("#{m}_with_traceview") do |*args, &blk|
            begin
              report_kvs = traceview_collect(m, args)
              args_length = args.length

              if m == :distinct && args_length >= 2
                report_kvs[:Key]   = args[0]
                report_kvs[:Query] = args[1].to_json if args[1] && args[1].class == Hash
              end

              if m == :find && args_length > 0
                report_kvs[:Limit] = args[0][:limit] if !args[0].nil? && args[0].key?(:limit)
              end

              if m == :group
                unless args.empty?
                  if args[0].is_a?(Hash)
                    report_kvs[:Group_Key]       = args[0][:key].to_json     if args[0].key?(:key)
                    report_kvs[:Group_Condition] = args[0][:cond].to_json    if args[0].key?(:cond)
                    report_kvs[:Group_Initial]   = args[0][:initial].to_json if args[0].key?(:initial)
                    report_kvs[:Group_Reduce]    = args[0][:reduce]          if args[0].key?(:reduce)
                  end
                end
              end
            rescue => e
              TraceView.logger.debug "[traceview/debug] #{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}" if TraceView::Config[:verbose]
            end

            TraceView::API.trace('mongo', report_kvs) do
              send("#{m}_without_traceview", *args, &blk)
            end
          end

          class_eval "alias #{m}_without_traceview #{m}"
          class_eval "alias #{m} #{m}_with_traceview"
        end

        # Instrument Collection index operations
        TraceView::Inst::Mongo::COLL_INDEX_OPS.reject { |m| !method_defined?(m) }.each do |m|
          define_method("#{m}_with_traceview") do |*args|
            report_kvs = traceview_collect(m, args)

            begin
              if [:create_index, :ensure_index, :drop_index].include?(m) && !args.empty?
                report_kvs[:Index] = args[0].to_json
              end
            rescue => e
              TraceView.logger.debug "[traceview/debug] #{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}" if TraceView::Config[:verbose]
            end

            TraceView::API.trace('mongo', report_kvs) do
              send("#{m}_without_traceview", *args)
            end
          end

          class_eval "alias #{m}_without_traceview #{m}"
          class_eval "alias #{m} #{m}_with_traceview"
        end
      end
    end
  end
end
