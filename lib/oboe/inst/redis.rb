# Copyright (c) 2014 AppNeta, Inc.
# All rights reserved.

module Oboe
  module Inst
    module Redis
      module Client
        def self.included(klass)
          ::Oboe::Util.method_alias(klass, :call, ::Redis::Client)
          ::Oboe::Util.method_alias(klass, :call_pipeline, ::Redis::Client)
        end

        # Given any Redis operation command array, this method
        # extracts the Key/Values to report to the TraceView
        # dashboard.
        #
        # @param command [Array] the Redis operation array
        # @param r [Return] the return value from the operation
        # @return [Hash] the Key/Values to report
        def extract_trace_details(command, r)
          kvs = {}
          op = command.first
 
          begin
            kvs[:KVOp] = command[0]
            kvs[:RemoteHost] = @options[:host]

            unless [ :keys, :randomkey, :scan, :sdiff, :sdiffstore, :sinter, 
                     :sinterstore, :smove, :sunion, :sunionstore, :zinterstore,
                     :zunionstore, :publish, :select, :eval, :evalsha, :script ].include? op or 
                     command[1].is_a?(Array)
              kvs[:KVKey] = command[1]
            end

            case op
            when :set
              if command.count > 3
                options = command[3]
                kvs[:ex] = options[:ex] if options.has_key?(:ex)
                kvs[:px] = options[:px] if options.has_key?(:px)
                kvs[:nx] = options[:nx] if options.has_key?(:nx)
                kvs[:xx] = options[:xx] if options.has_key?(:xx)
              end
            
            when :psetex, :restore, :setex, :setnx
              kvs[:ttl] = command[2]
            
            when :publish
              kvs[:channel] = command[1]

            when :sdiffstore, :sinterstore, :sunionstore, :zinterstore, :zunionstore
              kvs[:destination] = command[1]
            
            when :smove
              kvs[:source] = command[1]
              kvs[:destination] = command[2]

            when :rename, :renamenx
              kvs[:newkey] = command[2]

            when :brpoplpush, :rpoplpush
              kvs[:destination] = command[2]

            when :append, :blpop, :brpop, :decr, :del, :dump, :exists, 
                 :hgetall, :hkeys, :hlen, :hvals, :hmset, :incr, :linsert, 
                 :llen, :lpop, :lpush, :lpushx, :lrem, :lset, :ltrim, 
                 :persist, :pttl, :randomkey, :hscan, :scan, :rpop, :rpush, 
                 :rpushx, :sadd, :scard, :sdiff, :sinter, :sismember, 
                 :smembers, :strlen, :sort, :spop, :srandmember, :srem, 
                 :sscan, :sunion, :ttl, :type, :zadd, :zcard, :zcount, :zincrby, 
                 :zrangebyscore, :zrank, :zrem, :zremrangebyscore,
                 :zrevrank, :zrevrangebyscore, :zscore
              # Only collect the default KVOp and possibly KVKey (above)

            when :get
              kvs[:KVHit] = !r.nil?

            when :eval
              if command[1].length > 1024
                kvs[:script] = command[1][0..1023]
              else
                kvs[:script] = command[1]
              end
            
            when :evalsha
              kvs[:sha] = command[1]

            when :script
              kvs[:subcommand] = command[1]
              if command[1] == "load"
                if command[1].length > 1024
                  kvs[:script] = command[2][0..1023]
                else
                  kvs[:script] = command[2]
                end
              end

            when :mget
              if command[1].is_a?(Array)
                kvs[:KVKeyCount] = command[1].count 
              else
                kvs[:KVKeyCount] = command.count - 1
              end 
              values = r.select{ |i| i }
              kvs[:KVHitCount] = values.count
            
            when :hmget
              kvs[:KVKeyCount] = command.count - 2
              values = r.select{ |i| i }
              kvs[:KVHitCount] = values.count
           
            when :mset, :msetnx
              if command[1].is_a?(Array)
                kvs[:KVKeyCount] = command[1].count / 2
              else
                kvs[:KVKeyCount] = (command.count - 1) / 2
              end
            
            when :move
              kvs[:db] = command[2]
            
            when :select
              kvs[:db] = command[1]

            when :lindex
              kvs[:index] = command[2]
            
            when :getset
              kvs[:value] = command[2]

            when :getbit, :setbit, :setrange
              kvs[:offset] = command[2]
            
            when :getrange, :zrange
              kvs[:start] = command[2]
              kvs[:end] = command[3]
            
            when :keys
              kvs[:pattern] = command[1]
            
            when :incrby, :incrbyfloat
              kvs[:increment] = command[2]
            
            when :hincrby, :hincrbyfloat
              kvs[:field] = command[2]
              kvs[:increment] = command[3]

            when :hdel, :hexists, :hget, :hset, :hsetnx
              kvs[:field] = command[2] unless command[2].is_a?(Array)
              kvs[:KVHit] = !r.nil? if op == :hget

            when :expire
              kvs[:seconds] = command[2]
            
            when :pexpire, :pexpireat
              kvs[:milliseconds] = command[2]
            
            when :expireat
              kvs[:timestamp] = command[2]

            when :decrby
              kvs[:decrement] = command[2]

            when :bitcount, :lrange, :zremrangebyrank, :zrevrange
              kvs[:start] = command[2]
              kvs[:stop] = command[3]

            when :bitop
              kvs[:operation] = command[1]
              kvs[:destkey] = command[2]

            else
              Oboe.logger.debug "#{op} not collected!"
            end

          rescue StandardError => e
            Oboe.logger.debug "Error collecting redis KVs: #{e.message}"
            Oboe.logger.debug e.backtrace.join("\n")
          end

          kvs
        end

        # Extracts the Key/Values to report from a pipelined
        # call to the TraceView dashboard.
        #
        # @param pipeline [Redis::Pipeline] the Redis pipeline instance
        # @return [Hash] the Key/Values to report
        def extract_pipeline_details(pipeline)
          kvs = {}

          begin
            kvs[:RemoteHost] = @options[:host]

            command_count = pipeline.commands.count
            kvs[:KVOpCount] = command_count

            if pipeline.commands.first == :multi
              kvs[:KVOp] = :multi
            else
              kvs[:KVOp] = :pipeline
            end
           
            # Report pipelined operations  if the number
            # of ops is reasonable
            if command_count < 12
              ops = []
              pipeline.commands.each do |c|
                ops << c.first
              end
              kvs[:KVOps] = ops.join(", ")
            end
          rescue StandardError => e
            Oboe.logger.debug "[oboe/debug] Error extracting pipelined commands: #{e.message}"
            Oboe.logger.debug e.backtrace
          end
          kvs
        end

        def call_with_oboe(command, &block)
          if Oboe.tracing?
            ::Oboe::API.log_entry('redis', {})

            begin
              r = call_without_oboe(command, &block)
              report_kvs = extract_trace_details(command, r)
            rescue StandardError => e
              ::Oboe::API.log_exception('redis', e)
              raise
            ensure
              ::Oboe::API.log_exit('redis', report_kvs)
            end

          else
            call_without_oboe(command, &block)
          end
        end
        
        def call_pipeline_with_oboe(pipeline)
          if Oboe.tracing?
            report_kvs = {}

            # Fall back to the raw tracing API so we can pass KVs
            # back on exit (a limitation of the Oboe::API.trace 
            # block method)  This removes the need for an info
            # event
            ::Oboe::API.log_entry('redis', {})

            report_kvs = extract_pipeline_details(pipeline)

            begin
              call_pipeline_without_oboe(pipeline)
            rescue StandardError => e
              ::Oboe::API.log_exception('redis', e)
              raise
            ensure
              ::Oboe::API.log_exit('redis', report_kvs)
            end
          else
            call_pipeline_without_oboe(pipeline)
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

