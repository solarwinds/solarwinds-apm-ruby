# Copyright (c) 2012 by Tracelytics, Inc.
# All rights reserved.

module Oboe
  module Inst
    module Mongo

      def self.included(cls)
        cls.class_eval do
          puts "[oboe/loading] Instrumenting mongo" if Oboe::Config[:verbose]
          if ::Mongo::Collection.method_defined? :find
            alias find_without_oboe find
            alias find find_with_oboe
          else puts "[oboe/loading] Couldn't properly instrument Mongo::Collection.find().  Partial traces may occur."
          end
        end
      end

      def find_with_oboe(selector, opts)
        if Oboe::Config.tracing?
          kvs = {}
          kvs[:KVOp] = :find
          # FIXME:  Should we truncate this string in case
          # of very long selectors?
          # FIXME: to_s doesn't do what is expected in ruby 1.8.7 (nameblah)
          kvs[:KVKey] = selector.to_s

          Oboe::API.trace('mongo', kvs || {}) do
            find_without_oboe(selector, opts)
          end
        else
          find_without_oboe(selector, opts)
        end
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
end

