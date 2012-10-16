# Copyright (c) 2012 by Tracelytics, Inc.
# All rights reserved.

module Oboe
  module Inst
    module Mongo
      OPERATIONS = [ :create_index, :distinct, :drop, :drop_index, :drop_indexes, 
                     :ensure_index, :find, :find_and_modify, :group, :index_information, 
                     :insert, :map_reduce, :remove, :rename, :update ]
    end
  end
end

if defined?(::Mongo::Collection)
  module ::Mongo
    class Collection
      include Oboe::Inst::Mongo
      
      Oboe::Inst::Mongo::OPERATIONS.reject { |m| not method_defined?(m) }.each do |m|
        define_method("#{m}_with_oboe") do |*args|
          report_kvs = {}
          args_length = args.length
         
          report_kvs[:Flavor] = 'mongodb'

          report_kvs[:Database] = @db.name
          report_kvs[:RemoteHost] = @db.connection.host
          report_kvs[:RemotePort] = @db.connection.port
          report_kvs[:Collection] = @name

          report_kvs[:QueryOp] = m 
          report_kvs[:Query] = args[0].try(:to_json) if args_length and args[0].class == Hash

          if [:create_index, :ensure_index, :drop_index].include? m and args_length 
            report_kvs[:Index] = args[0].try(:to_json)
          end

          if m == :group
            if args_length 
              if args[0].is_a?(Hash) 
                report_kvs[:Group_Key]       = args[0][:key].try(:to_json)     if args[0].has_key?(:key)
                report_kvs[:Group_Condition] = args[0][:cond].try(:to_json)    if args[0].has_key?(:cond) 
                report_kvs[:Group_Initial]   = args[0][:initial].try(:to_json) if args[0].has_key?(:initial)
                report_kvs[:Group_Reduce]    = args[0][:reduce]                if args[0].has_key?(:reduce) 
              end
            end
          end

          if m == :update
            if args_length >= 3
              report_kvs[:Update_Document] = args[1].try(:to_json)
              report_kvs[:Multi] = args[2][:multi] if args[2] and args[2].has_key?(:multi)
            end
          end

          if m == :find_and_modify and args[0] and args[0].has_key?(:update)
            report_kvs[:Update_Document] = args[0][:update]
          end

          if m == :distinct and args_length >= 2
            report_kvs[:key] = args[0]
            report_kvs[:Query] = args[1].try(:to_json) if args[1].class == Hash
          end

          report_kvs[:New_Collection_Name] = args[0] if m == :rename
          report_kvs[:Collection_Name] = @name       if m == :drop

          if m == :map_reduce
            report_kvs[:Map_Function]    = args[0] 
            report_kvs[:Reduce_Function] = args[1]
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
  puts "[oboe/loading] Instrumenting mongo" if Oboe::Config[:verbose]
end

