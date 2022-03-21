# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'json'

if SolarWindsAPM::Config[:mongo][:enabled]
  if defined?(Mongo) && (Gem.loaded_specs['mongo'].version.to_s >= '2.0.0')
    SolarWindsAPM.logger.info '[appoptics_apm/loading] Instrumenting mongo' if SolarWindsAPM::Config[:verbose]

    # Collection Related Operations
    COLL_OTHER_OPS = [:create, :drop, :insert_one, :insert_many, :bulk_write, :map_reduce].freeze

    # Mongo 2.2 only ops
    if Mongo::VERSION >= '2.1'
      COLL_QUERY_OPS = [:find, :find_one_and_delete, :find_one_and_update, :find_one_and_replace, :update_one, :update_many, :delete_one, :delete_many, :replace_one].freeze
    else
      COLL_QUERY_OPS = [:find, :update_many, :delete_one].freeze
    end

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

          if op == :map_reduce
            kvs[:Map_Function] = args[0]
            kvs[:Reduce_Function] = args[1]
            kvs[:Limit] = args[2][:limit] if args[2].is_a?(Hash) && args[2].key?(:limit)
          end

          if SolarWindsAPM::Config[:mongo][:log_args]
            if COLL_QUERY_OPS.include?(op)
              kvs[:Query] = args.first.to_json
            end
          end

          kvs[:RemoteHost] = @database.client.cluster.addresses.first.to_s
          kvs[:Backtrace] = SolarWindsAPM::API.backtrace if SolarWindsAPM::Config[:mongo][:collect_backtraces]
        rescue => e
          SolarWindsAPM.logger.debug "[appoptics_apm/debug] #{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}" if SolarWindsAPM::Config[:verbose]
        ensure
          return kvs
        end

        ##
        # Here we dynamically define wrapper methods for the operations
        # we want to instrument in mongo
        #
        COLL_OPS.reject { |m| !method_defined?(m) }.each do |m|
          define_method("#{m}_with_appoptics") do |*args|
            begin
              if !SolarWindsAPM.tracing? || SolarWindsAPM.tracing_layer?(:mongo)
                mongo_skipped = true
                return send("#{m}_without_appoptics", *args)
              end

              kvs = collect_kvs(m, args)
              SolarWindsAPM::API.log_entry(:mongo, kvs)

              send("#{m}_without_appoptics", *args)
            rescue => e
              SolarWindsAPM::API.log_exception(:mongo, e)
              raise e
            ensure
              SolarWindsAPM::API.log_exit(:mongo) unless mongo_skipped
            end
          end
          SolarWindsAPM::Util.method_alias(Mongo::Collection, m)
        end
      end
    end

    ##
    # Mongo Collection View Instrumentation
    #

    # Collection View Related Operations
    VIEW_QUERY_OPS = [:delete_one, :delete_many, :count, :distinct, :find_one_and_delete, :find_one_and_update,
                      :replace_one, :update_one, :update_many].freeze
    VIEW_OTHER_OPS = [:aggregate, :map_reduce ].freeze
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
            kvs[:Collection] = @collection.name

            if op == :map_reduce
              kvs[:Map_Function] = args[0]
              kvs[:Reduce_Function] = args[1]
              kvs[:Limit] = args[2][:limit] if args[2].is_a?(Hash) && args[2].key?(:limit)
            end

            if SolarWindsAPM::Config[:mongo][:log_args]
              if VIEW_QUERY_OPS.include?(op)
                if defined?(filter)
                  kvs[:Query] = filter.to_json
                elsif defined?(selector)
                  kvs[:Query] = selector.to_json
                end
              end
            end

            kvs[:RemoteHost] = @collection.database.client.cluster.addresses.first.to_s
            kvs[:Backtrace] = SolarWindsAPM::API.backtrace if SolarWindsAPM::Config[:mongo][:collect_backtraces]
          rescue => e
            SolarWindsAPM.logger.debug "[appoptics_apm/debug] #{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}" if SolarWindsAPM::Config[:verbose]
          ensure
            return kvs
          end

          ##
          # Here we dynamically define wrapper methods for the operations
          # we want to instrument in mongo
          #
          VIEW_OPS.reject { |m| !method_defined?(m) }.each do |m|
            define_method("#{m}_with_appoptics") do |*args|
              begin
                if !SolarWindsAPM.tracing? || SolarWindsAPM.tracing_layer?(:mongo)
                  mongo_skipped = true
                  return send("#{m}_without_appoptics", *args)
                end

                kvs = collect_kvs(m, args)
                SolarWindsAPM::API.log_entry(:mongo, kvs)

                send("#{m}_without_appoptics", *args)
              rescue => e
                SolarWindsAPM::API.log_exception(:mongo, e)
                raise e
              ensure
                SolarWindsAPM::API.log_exit(:mongo) unless mongo_skipped
              end
            end
            SolarWindsAPM::Util.method_alias(Mongo::Collection::View, m)
          end
        end
      end
    end

    ##
    # Mongo Collection Index View Instrumentation
    #

    # Collection Index View Related Operations
    INDEX_OPS = [:create_one, :create_many, :drop_one, :drop_all].freeze

    module Mongo
      module Index
        class View
          ##
          # collect_kvs
          #
          # Used to collect up information to report and build a hash
          # with the Keys/Values to report.
          #
          def collect_index_kvs(op, args)
            kvs = { :Flavor => :mongodb, :Database => @collection.database.name }

            kvs[:QueryOp] = op
            kvs[:Collection] = @collection.name
            kvs[:RemoteHost] = @collection.database.client.cluster.addresses.first.to_s
            kvs[:Backtrace] = SolarWindsAPM::API.backtrace if SolarWindsAPM::Config[:mongo][:collect_backtraces]
          rescue => e
            SolarWindsAPM.logger.debug "[appoptics_apm/debug] #{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}" if SolarWindsAPM::Config[:verbose]
          ensure
            return kvs
          end

          ##
          # Here we dynamically define wrapper methods for the operations
          # we want to instrument in mongo
          #
          INDEX_OPS.reject { |m| !method_defined?(m) }.each do |m|
            define_method("#{m}_with_appoptics") do |*args|
              begin
                if !SolarWindsAPM.tracing? || SolarWindsAPM.tracing_layer?(:mongo)
                  mongo_skipped = true
                  return send("#{m}_without_appoptics", *args)
                end

                kvs = collect_index_kvs(m, args)
                SolarWindsAPM::API.log_entry(:mongo, kvs)

                send("#{m}_without_appoptics", *args)
              rescue => e
                SolarWindsAPM::API.log_exception(:mongo, e)
                raise e
              ensure
                SolarWindsAPM::API.log_exit(:mongo) unless mongo_skipped
              end
            end
            SolarWindsAPM::Util.method_alias(Mongo::Index::View, m)
          end
        end
      end
    end
  end
end
