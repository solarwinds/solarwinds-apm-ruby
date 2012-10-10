# Copyright (c) 2012 by Tracelytics, Inc.
# All rights reserved.

module Oboe
  module Inst
    module Mongo
      OPERATIONS = [ :find, :insert, :remove, :update, :create_index, :ensure_index,
                     :drop_index, :drop_indexes, :drop, :find_and_modify, :map_reduce, 
                     :group, :distinct, :rename, :index_information ]
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
         
          report_kvs[:Flavor] = 'mongodb'

          report_kvs[:Database] = @db.name
          report_kvs[:RemoteHost] = @db.connection.host
          report_kvs[:RemotePort] = @db.connection.port
          report_kvs[:Collection] = @name

          report_kvs[:QueryOp] = m 
          report_kvs[:QueryKey] = args[0].to_json if args.length and args[0].class == Hash

          if [:create_index, :ensure_index, :drop_index].include? m and args.length 
            report_kvs[:Index] = args[0].to_json
          end

          if m == :group
            if args.length > 1 and args[0].class == Hash
              opts = args[0]
              report_kvs[:Group_Key]        = opts[:key].to_json      if opts.has_key?(:key)
              report_kvs[:Group_Condition]  = opts[:cond].to_json     if opts.has_key?(:cond)
              report_kvs[:Group_Initial]    = opts[:initial].to_json  if opts.has_key?(:initial)
              report_kvs[:Group_Reduce]     = opts[:reduce].to_json   if opts.has_key?(:reduce)
            end
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

