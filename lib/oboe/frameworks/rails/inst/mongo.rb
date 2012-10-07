# Copyright (c) 2012 by Tracelytics, Inc.
# All rights reserved.

module Oboe
  module Inst
    module Mongo
      OPERATIONS = [ :find, :update, :insert, :remove, :drop, :index, :group, :distinct, :find_and_modify ]
    
      OPERATIONS.reject { |m| not method_defined?(m) }.each do |m|
        define_method("#{m}_with_oboe") do |*args|
          opts = { :KVOp => m }
          opts[:KVKey] = args[0].to_s if args.length and args[0].class == Hash

          Oboe::API.trace('mongo', opts) do
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
    end
  end
  puts "[oboe/loading] Instrumenting mongo" if Oboe::Config[:verbose]
end

