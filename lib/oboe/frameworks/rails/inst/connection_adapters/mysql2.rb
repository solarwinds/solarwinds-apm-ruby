# Copyright (c) 2013 by AppNeta
# All rights reserved.

module Oboe
  module Inst
    module ConnectionAdapters
      module FlavorInitializers
        def self.mysql2
          Oboe.logger.info "[oboe/loading] Instrumenting activerecord mysql2adapter" if Oboe::Config[:verbose]
            
          Oboe::Util.send_include(::ActiveRecord::ConnectionAdapters::Mysql2Adapter,
                                    Oboe::Inst::ConnectionAdapters::Utils)

          if (::ActiveRecord::VERSION::MAJOR == 3 and ::ActiveRecord::VERSION::MINOR == 0) or
              ::ActiveRecord::VERSION::MAJOR == 2 
            # ActiveRecord 3.0 and prior
            Oboe::Util.method_alias(::ActiveRecord::ConnectionAdapters::Mysql2Adapter, :execute)
          else
            # ActiveRecord 3.1 and above
            Oboe::Util.method_alias(::ActiveRecord::ConnectionAdapters::Mysql2Adapter, :exec_insert)
            Oboe::Util.method_alias(::ActiveRecord::ConnectionAdapters::Mysql2Adapter, :exec_query)
            Oboe::Util.method_alias(::ActiveRecord::ConnectionAdapters::Mysql2Adapter, :exec_delete)
          end
        end
      end
    end
  end
end
