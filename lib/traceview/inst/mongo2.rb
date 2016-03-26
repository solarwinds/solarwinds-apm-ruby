# Copyright (c) 2013 AppNeta, Inc.
# All rights reserved.

require 'json'

if RUBY_VERSION >= '1.9' && TraceView::Config[:mongo][:enabled]
  if defined?(::Mongo) && (Gem.loaded_specs['mongo'].version.to_s >= '2.0.0')
    ::TraceView.logger.info '[traceview/loading] Instrumenting mongo' if TraceView::Config[:verbose]

    # Collection Related Operations
    COLL_QUERY_OPS = [:find, :find_one_and_delete, :find_one_and_update, :find_one_and_replace, :update_one, :update_many,
                       :delete_one, :delete_many, :replace_one]
    COLL_OTHER_OPS = [:create, :drop, :insert_one, :insert_many, :bulk_write, :map_reduce]
    COLL_OPS = COLL_QUERY_OPS + COLL_OTHER_OPS

    module Mongo
      class Collection
        ##
        # collect_kvs
        #
        # Used to collect up information to report and build a hash
        # with the Keys/Values to report.
        #
        def collect_kvs(op, args)
          kvs = { :Flavor => :mongodb, :Database => @database.name }

          kvs[:QueryOp] = op

          if op == :create
            kvs[:New_Collection_Name] = @name
          else
            kvs[:Collection] = @name
          end

          if TraceView::Config[:mongo][:log_args]
            if COLL_QUERY_OPS.include?(op)
              kvs[:Query] = args.first.to_json
            end
          end

          kvs[:RemoteHost] = @database.client.cluster.addresses.first.to_s
          kvs[:Backtrace] = TraceView::API.backtrace if TraceView::Config[:mongo][:collect_backtraces]
        rescue => e
          TraceView.logger.debug "[traceview/debug] #{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}" if TraceView::Config[:verbose]
        ensure
          return kvs
        end

        ##
        # Here we dynamically define wrapper methods for the operations
        # we want to instrument in mongo
        #
        COLL_OPS.reject { |m| !method_defined?(m) }.each do |m|
          define_method("#{m}_with_traceview") do |*args|
            begin
              if !TraceView.tracing? || TraceView.tracing_layer?(:mongo)
                mongo_skipped = true
                return send("#{m}_without_traceview", *args)
              end

              kvs = collect_kvs(m, args)
              TraceView::API.log_entry(:mongo, kvs)

              send("#{m}_without_traceview", *args)
            rescue => e
              TraceView::API.log_exception(:mongo, e)
              raise e
            ensure
              TraceView::API.log_exit(:mongo) unless mongo_skipped
            end
          end
          ::TraceView::Util.method_alias(Mongo::Collection, m)
        end
      end
    end

    ##
    # Mongo Collection View Instrumentation
    #

    # Collection View Related Operations
    VIEW_QUERY_OPS = [:count, :distinct ]
    VIEW_OTHER_OPS = [:aggregate]
    VIEW_OPS = VIEW_QUERY_OPS + VIEW_OTHER_OPS

    module Mongo
      class Collection
        class View
          ##
          # collect_kvs
          #
          # Used to collect up information to report and build a hash
          # with the Keys/Values to report.
          #
          def collect_kvs(op, args)
            kvs = { :Flavor => :mongodb, :Database => @collection.database.name }

            kvs[:QueryOp] = op

            if op == :create
              kvs[:New_Collection_Name] = @collection.name
            else
              kvs[:Collection] = @collection.name
            end

            if TraceView::Config[:mongo][:log_args]
              if VIEW_QUERY_OPS.include?(op)
                kvs[:Query] = filter.to_json
              end
            end

            kvs[:RemoteHost] = @collection.database.client.cluster.addresses.first.to_s
            kvs[:Backtrace] = TraceView::API.backtrace if TraceView::Config[:mongo][:collect_backtraces]
          rescue => e
            TraceView.logger.debug "[traceview/debug] #{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}" if TraceView::Config[:verbose]
          ensure
            return kvs
          end

          ##
          # Here we dynamically define wrapper methods for the operations
          # we want to instrument in mongo
          #
          VIEW_OPS.reject { |m| !method_defined?(m) }.each do |m|
            define_method("#{m}_with_traceview") do |*args|
              begin
                if !TraceView.tracing? || TraceView.tracing_layer?(:mongo)
                  mongo_skipped = true
                  return send("#{m}_without_traceview", *args)
                end

                kvs = collect_kvs(m, args)
                TraceView::API.log_entry(:mongo, kvs)

                send("#{m}_without_traceview", *args)
              rescue => e
                TraceView::API.log_exception(:mongo, e)
                raise e
              ensure
                TraceView::API.log_exit(:mongo) unless mongo_skipped
              end
            end
            ::TraceView::Util.method_alias(Mongo::Collection::View, m)
          end
        end
      end
    end
  end
end
