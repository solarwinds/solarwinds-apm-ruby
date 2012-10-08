# Copyright (c) 2012 by Tracelytics, Inc.
# All rights reserved.

module Oboe
  module Inst
    module Mongo
      OPERATIONS = [ :find, :find_one, :save, :insert, :remove, :update, 
                     :create_index, :ensure_index, :drop_index, :drop_indexes, :drop, 
                     :find_and_modify, :map_reduce, :group, :distinct, :rename, 
                     :index_information ]
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
          
          report_kvs[:KVOp] = m 
          report_kvs[:KVKey] = args[0].to_json if args.length and args[0].class == Hash

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

