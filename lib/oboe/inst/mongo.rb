# Copyright (c) 2012 by Tracelytics, Inc.
# All rights reserved.

module Oboe
  module Inst
    module Mongo
      FLAVOR = 'mongodb'

      # Operations for Mongo::DB
      DB_OPS         = [ :create_collection, :drop_collection ]

      # Operations for Mongo::Cursor
      CURSOR_OPS     = [ :count ]
      
      # Operations for Mongo::Collection
      COLL_WRITE_OPS = [ :find_and_modify, :insert, :map_reduce, :remove, :rename, :update ]
      COLL_QUERY_OPS = [ :distinct, :find, :group ]
      COLL_INDEX_OPS = [ :create_index, :drop_index, :drop_indexes, :ensure_index, :index_information ]
    end
  end
end

if defined?(::Mongo) and Oboe::Config[:mongo][:enabled]
  Oboe.logger.info "[oboe/loading] Instrumenting mongo" if Oboe::Config[:verbose]

  if defined?(::Mongo::DB)
    module ::Mongo
      class DB
        include Oboe::Inst::Mongo
        
        # Instrument DB operations
        Oboe::Inst::Mongo::DB_OPS.reject { |m| not method_defined?(m) }.each do |m|
          define_method("#{m}_with_oboe") do |*args|
            report_kvs = {}

            begin
              report_kvs[:Flavor] = Oboe::Inst::Mongo::FLAVOR

              report_kvs[:Database] = @name
              report_kvs[:RemoteHost] = @connection.host
              report_kvs[:RemotePort] = @connection.port
              
              report_kvs[:QueryOp] = m 

              report_kvs[:New_Collection_Name] = args[0] if m == :create_collection
              report_kvs[:Collection_Name] = args[0]     if m == :drop_collection

              report_kvs[:Backtrace] = Oboe::API.backtrace
            rescue
            end

            Oboe::API.trace('mongo', report_kvs) do
              send("#{m}_without_oboe", *args)
            end
          end
          
          class_eval "alias #{m}_without_oboe #{m}"
          class_eval "alias #{m} #{m}_with_oboe"
        end
      end
    end
  end

  if defined?(::Mongo::Cursor)
    module ::Mongo
      class Cursor
        include Oboe::Inst::Mongo
        
        # Instrument DB cursor operations
        Oboe::Inst::Mongo::CURSOR_OPS.reject { |m| not method_defined?(m) }.each do |m|
          define_method("#{m}_with_oboe") do |*args|
            report_kvs = {}
            
            begin
              report_kvs[:Flavor] = Oboe::Inst::Mongo::FLAVOR

              report_kvs[:Database] = @db.name
              report_kvs[:RemoteHost] = @connection.host
              report_kvs[:RemotePort] = @connection.port

              report_kvs[:QueryOp] = m 
              if m == :count
                unless @selector.empty?
                  report_kvs[:Query] = @selector.try(:to_json) 
                else
                  report_kvs[:Query] = 'all'
                end
                report_kvs[:Limit] = @limit if @limit != 0
              end
            rescue
            end
            
            Oboe::API.trace('mongo', report_kvs) do
              send("#{m}_without_oboe", *args)
            end
          end
          
          class_eval "alias #{m}_without_oboe #{m}"
          class_eval "alias #{m} #{m}_with_oboe"
        end
      end
    end
  end

  if defined?(::Mongo::Collection)
    module ::Mongo
      class Collection
        include Oboe::Inst::Mongo

        def oboe_collect(m, args)
          report_kvs = {}
          report_kvs[:Flavor] = Oboe::Inst::Mongo::FLAVOR

          report_kvs[:Database] = @db.name
          report_kvs[:RemoteHost] = @db.connection.host
          report_kvs[:RemotePort] = @db.connection.port
          report_kvs[:Collection] = @name
              
          report_kvs[:Backtrace] = Oboe::API.backtrace

          report_kvs[:QueryOp] = m 
          report_kvs[:Query] = args[0].try(:to_json) if args and not args.empty? and args[0].class == Hash
          report_kvs
        end
        
        # Instrument Collection write operations
        Oboe::Inst::Mongo::COLL_WRITE_OPS.reject { |m| not method_defined?(m) }.each do |m|
          define_method("#{m}_with_oboe") do |*args|
            report_kvs = oboe_collect(m, args)
            args_length = args.length
            
            begin
              if m == :find_and_modify and args[0] and args[0].has_key?(:update)
                report_kvs[:Update_Document] = args[0][:update]
              end

              if m == :map_reduce
                report_kvs[:Map_Function]    = args[0] 
                report_kvs[:Reduce_Function] = args[1]
                report_kvs[:Limit] = args[2][:limit] if args[2] and args[2].has_key?(:limit)
              end

              report_kvs[:New_Collection_Name] = args[0] if m == :rename

              if m == :update
                if args_length >= 3
                  report_kvs[:Update_Document] = args[1].try(:to_json)
                  report_kvs[:Multi] = args[2][:multi] if args[2] and args[2].has_key?(:multi)
                end
              end
            rescue
            end
            
            Oboe::API.trace('mongo', report_kvs) do
              send("#{m}_without_oboe", *args)
            end
          end

          class_eval "alias #{m}_without_oboe #{m}"
          class_eval "alias #{m} #{m}_with_oboe"
        end
        
        # Instrument Collection query operations
        Oboe::Inst::Mongo::COLL_QUERY_OPS.reject { |m| not method_defined?(m) }.each do |m|
          define_method("#{m}_with_oboe") do |*args|
            begin
              report_kvs = oboe_collect(m, args)
              args_length = args.length

              if m == :distinct and args_length >= 2
                report_kvs[:Key]   = args[0]
                report_kvs[:Query] = args[1].try(:to_json) if args[1] and args[1].class == Hash
              end

              if m == :find and args_length > 0
                report_kvs[:Limit] = args[0][:limit] if !args[0].nil? and args[0].has_key?(:limit)
              end

              if m == :group
                unless args.empty?
                  if args[0].is_a?(Hash) 
                    report_kvs[:Group_Key]       = args[0][:key].try(:to_json)     if args[0].has_key?(:key)
                    report_kvs[:Group_Condition] = args[0][:cond].try(:to_json)    if args[0].has_key?(:cond) 
                    report_kvs[:Group_Initial]   = args[0][:initial].try(:to_json) if args[0].has_key?(:initial)
                    report_kvs[:Group_Reduce]    = args[0][:reduce]                if args[0].has_key?(:reduce) 
                  end
                end
              end
            rescue
            end

            Oboe::API.trace('mongo', report_kvs) do
              send("#{m}_without_oboe", *args)
            end
          end

          class_eval "alias #{m}_without_oboe #{m}"
          class_eval "alias #{m} #{m}_with_oboe"
        end
        
        # Instrument Collection index operations
        Oboe::Inst::Mongo::COLL_INDEX_OPS.reject { |m| not method_defined?(m) }.each do |m|
          define_method("#{m}_with_oboe") do |*args|
            report_kvs = oboe_collect(m, args)
            _args = args || []
           
            begin
              if [:create_index, :ensure_index, :drop_index].include? m and not _args.empty?
                report_kvs[:Index] = _args[0].try(:to_json)
              end
            rescue
            end

            Oboe::API.trace('mongo', report_kvs) do
              send("#{m}_without_oboe", *args)
            end
          end

          class_eval "alias #{m}_without_oboe #{m}"
          class_eval "alias #{m} #{m}_with_oboe"
        end
      end
    end
  end
end

