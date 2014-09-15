# Copyright (c) 2013 AppNeta, Inc.
# All rights reserved.

module Oboe
  module Inst
    module ConnectionAdapters
      module FlavorInitializers
        def self.oracle
          Oboe.logger.info '[oboe/loading] Instrumenting activerecord oracleenhancedadapter' if Oboe::Config[:verbose]
          ::ActiveRecord::ConnectionAdapters::OracleEnhancedAdapter.module_eval do
            include Oboe::Inst::ConnectionAdapters
          end if defined?(::ActiveRecord::ConnectionAdapters::OracleEnhancedAdapter)
        end
      end
    end
  end
end

