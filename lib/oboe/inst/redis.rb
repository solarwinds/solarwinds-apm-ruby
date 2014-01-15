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

            # mget, mset
            unless [ :keys, :randomkey, :scan, :sdiff, :sdiffstore, :sinter, 
                     :sinterstore, :sscan, :smove, :sunion, :sunionstore, :zinterstore,
                     :zunionstore, :publish, :select ].include? op or 
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
                 :get, :hgetall, :hkeys, 
                 :hlen, :hvals, :hmget, :hmset, :incr, :linsert, :llen, 
                 :lpop, :lpush, :lpushx, :lrem, :lset, :ltrim, :mget, :mset, :msetnx, :persist, :pttl, 
                 :randomkey, :hscan, :scan, :rpop, :rpush, :rpushx, :sadd, :scard, :sdiff, :sinter,
                 :sismember, :smembers, :strlen, :sort, :spop, :srandmember, :srem, :sunion, :ttl,
                 :zadd, :zcard, :zcount, :zincrby, :zrangebyscore, :zrank, :zrem, :zremrangebyscore,
                 :zrevrank, :zrevrangebyscore, :zscore
              # Only collect the default KVOp and possibly KVKey (above)
            
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

            # Not implemented: :migrate, :object

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

