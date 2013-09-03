# Copyright (c) 2013 by AppNeta
# All rights reserved.

module Oboe
  module Inst
    module ConnectionAdapters

      module Mysql2Adapter
        include Oboe::Inst::ConnectionAdapters::Utils
      
        def self.included(cls)
          cls.class_eval do
            if ::Rails::VERSION::MAJOR == 2 or (::Rails::VERSION::MAJOR == 3 and ::Rails::VERSION::MINOR == 0)
              if ActiveRecord::ConnectionAdapters::Mysql2Adapter::method_defined? :execute
                alias execute_without_oboe execute
                alias execute execute_with_oboe
              else Oboe.logger.warn "[oboe/loading] Couldn't properly instrument activerecord layer.  Partial traces may occur."
              end
            else
              if ActiveRecord::ConnectionAdapters::Mysql2Adapter::method_defined? :exec_insert
                alias exec_insert_without_oboe exec_insert
                alias exec_insert exec_insert_with_oboe
              else Oboe.logger.warn "[oboe/loading] Couldn't properly instrument activerecord layer.  Partial traces may occur."
              end
             
              # In Rails 3.1, exec_query was defined as a private method
              if ActiveRecord::ConnectionAdapters::Mysql2Adapter::method_defined? :exec_query or
                ActiveRecord::ConnectionAdapters::Mysql2Adapter::private_method_defined? :exec_query
                alias exec_query_without_oboe exec_query
                alias exec_query exec_query_with_oboe
              else Oboe.logger.warn "[oboe/loading] Couldn't properly instrument activerecord layer.  Partial traces may occur."
              end
              
              if ActiveRecord::ConnectionAdapters::Mysql2Adapter::method_defined? :exec_delete
                alias exec_delete_without_oboe exec_delete
                alias exec_delete exec_delete_with_oboe
              else Oboe.logger.warn "[oboe/loading] Couldn't properly instrument activerecord layer.  Partial traces may occur."
              end
            end
          end
        end
      end # Mysql2Adapter

      module FlavorInitializers
        def self.mysql2
          Oboe.logger.info "[oboe/loading] Instrumenting activerecord mysql2adapter" if Oboe::Config[:verbose]
          ::ActiveRecord::ConnectionAdapters::Mysql2Adapter.module_eval do
            include Oboe::Inst::ConnectionAdapters::Mysql2Adapter
          end if defined?(::ActiveRecord::ConnectionAdapters::Mysql2Adapter)
        end
      end

    end
  end
end
