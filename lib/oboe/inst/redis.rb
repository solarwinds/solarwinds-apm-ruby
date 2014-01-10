# Copyright (c) 2014 AppNeta, Inc.
# All rights reserved.

module Oboe
  module Inst
    module Redis
      module Client
        def self.included(klass)
          ::Oboe::Util.method_alias(klass, :call, ::Redis::Client)
        end

        def extract_trace_details(command)
          kvs = {}
          op = command.first
 
          begin
            kvs[:KVOp] = command[0]
            kvs[:KVKey] = command[1]

            case op
            when :set
              if command.count > 3
                options = command[3]
                kvs[:ex] = options[:ex] if options.has_key?(:ex)
                kvs[:px] = options[:px] if options.has_key?(:px)
                kvs[:nx] = options[:nx] if options.has_key?(:nx)
                kvs[:xx] = options[:xx] if options.has_key?(:xx)
              end
            when :setex, :setnx, :psetex
              kvs[:ttl] = command[2]
              kvs[:value] = command[3]

            when :append, :decr, :get, :getset, :incr, :strlen
              # Only collect the default KVOp/KVKey (above)
            
            when :getbit, :setbit, :setrange
              kvs[:offset] = command[2]
            
            when :getrange
              kvs[:start] = command[2]
              kvs[:end] = command[3]
            
            when :incrby, :incrbyfloat
              kvs[:increment] = command[2]

            when :decrby
              kvs[:decrement] = command[2]

            when :bitcount
              kvs[:start] = command[2]
              kvs[:stop] = command[3]

            when :bitop
              kvs[:operation] = command[2]
              kvs[:destkey] = command[3]

            else
              Oboe.logger.debug "#{op} not collected!"
            end

          rescue StandardError => e
            Oboe.logger.debug "Error collecting redis KVs: #{e.message}"
          end

          kvs
        end

        def call_with_oboe(command, &block)
          if Oboe.tracing?
            report_kvs = extract_trace_details(command)

            Oboe::API.trace('redis', report_kvs) do
              call_without_oboe(command, &block)
            end
          else
            call_without_oboe(command, &block)
          end
        end

      end
    end
  end
end

if Oboe::Config[:redis][:enabled] 
  if defined?(Redis) and (Redis::VERSION =~ /^3\./) == 0 
    Oboe.logger.info "[oboe/loading] Instrumenting redis" if Oboe::Config[:verbose]
    ::Oboe::Util.send_include(::Redis::Client, ::Oboe::Inst::Redis::Client)
  end
end

