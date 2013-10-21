# Copyright (c) 2013 AppNeta, Inc.
# All rights reserved.

module Oboe
  module Util
    class << self
      ##
      # oboe_alias
      #
      # Centralized utility method to alias a method on an arbitrary
      # class or module.
      #
      def method_alias(cls, method, name=nil)
        # Attempt to infer a contextual name if not indicated
        #
        # For example:
        # ::ActiveRecord::ConnectionAdapters::AbstractMysqlAdapter.to_s.split(/::/).last
        # => "AbstractMysqlAdapter"
        #
        begin
          name ||= cls.to_s.split(/::/).last 
        rescue
        end

        if cls.method_defined? method.to_sym or cls.private_method_defined? method.to_sym
          cls.class_eval do
            alias_method "#{method}_without_oboe", "#{method}"
            alias_method "#{method}", "#{method}_with_oboe"
          end
        else Oboe.logger.warn "[oboe/loading] Couldn't properly instrument #{name}.  Partial traces may occur."
        end
      end
  
      ##
      # oboe_send_include
      #
      # Centralized utility method to send a include call for an
      # arbitrary class
      def send_include(target_cls, cls)
        if defined?(target_cls)
          target_cls.send(:include, cls)
        end
      end
    end
  end
end

