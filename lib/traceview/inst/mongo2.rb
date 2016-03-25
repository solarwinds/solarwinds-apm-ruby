# Copyright (c) 2013 AppNeta, Inc.
# All rights reserved.

require 'json'

if RUBY_VERSION >= '1.9' && TraceView::Config[:mongo][:enabled]
  if defined?(::Mongo) && (Gem.loaded_specs['mongo'].version.to_s >= '2.0.0')
    ::TraceView.logger.info '[traceview/loading] Instrumenting mongo' if TraceView::Config[:verbose]

    MONGO_OPS = [:create, :drop, :insert_one, :insert_many, :find, :find_one_and_delete, :find_one_and_update,
                  :find_one_and_replace]

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
            if [:find, :find_one_and_delete, :find_one_and_update, :find_one_and_replace].include?(op)
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
        MONGO_OPS.reject { |m| !method_defined?(m) }.each do |m|
          define_method("#{m}_with_traceview") do |*args|
            begin
              if !TraceView.tracing? || TraceView.tracing_layer?(:mongo)
                mongo_skipped = true
                return send("#{m}_without_traceview", *args)
              end

              #TV.pry! if m == :find

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
  end
end
