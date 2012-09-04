# Copyright (c) 2012 by Tracelytics, Inc.
# All rights reserved.

module Oboe
  module Inst
    module Dalli
      def self.included(cls)
        cls.class_eval do
          puts "[oboe_fu/loading] Instrumenting Memcache (Dalli)" if Oboe::Config[:verbose]
          if ::Dalli::Client.private_method_defined? :perform
            alias perform_without_oboe perform
            alias perform perform_with_oboe
          else puts "[oboe_fu/loading] Couldn't properly instrument Memcache (Dalli).  Partial traces may occur."
          end
        end
      end

      def perform_with_oboe(op, key, *args)
        if Oboe::Config.tracing?
          opts = {}
          opts[:KVOp] = op
          opts[:KVKey] = key 

          Oboe::API.trace('memcache', opts || {}) do
            perform_without_oboe(op, key, *args)
          end
        else
          perform_without_oboe(op, key, *args)
        end
      end
    end
  end
end

if defined?(Dalli)
  if Rails::VERSION::MAJOR == 3
    Rails.configuration.after_initialize do
      Dalli::Client.module_eval do
        include Oboe::Inst::Dalli
      end
    end
  else
    Dalli::Client.module_eval do
      include Oboe::Inst::Dalli
    end
  end
end
