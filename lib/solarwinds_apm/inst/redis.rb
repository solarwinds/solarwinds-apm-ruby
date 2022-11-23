# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

module SolarWindsAPM
  module Inst
    module Redis
      module Client
        # The operations listed in this constant skip collecting KVKey
        NO_KEY_OPS = [:auth, :keys, :randomkey, :scan, :sdiff, :sdiffstore, :sinter,
                      :sinterstore, :smove, :sunion, :sunionstore, :zinterstore,
                      :zunionstore, :publish, :select, :eval, :evalsha, :script].freeze

        # Instead of a giant switch statement, we use a hash constant to map out what
        # KVs need to be collected for each of the many many Redis operations
        # Hash formatting by undiagnosed OCD
        KV_COLLECT_MAP = {
          :brpoplpush  => { :destination  => 2 }, :rpoplpush   => { :destination  => 2 },
          :sdiffstore  => { :destination  => 1 }, :sinterstore => { :destination  => 1 },
          :sunionstore => { :destination  => 1 }, :zinterstore => { :destination  => 1 },
          :zunionstore => { :destination  => 1 }, :publish     => { :channel      => 1 },
          :incrby      => { :increment    => 2 }, :incrbyfloat => { :increment    => 2 },
          :pexpire     => { :milliseconds => 2 }, :pexpireat   => { :milliseconds => 2 },
          :expireat    => { :timestamp    => 2 }, :decrby      => { :decrement    => 2 },
          :psetex      => { :ttl     => 2 },      :restore  => { :ttl     => 2 },
          :setex       => { :ttl     => 2 },      :setnx    => { :ttl     => 2 },
          :move        => { :db      => 2 },      :select   => { :db      => 1 },
          :lindex      => { :index   => 2 },      :getset   => { :value   => 2 },
          :keys        => { :pattern => 1 },      :expire   => { :seconds => 2 },
          :rename      => { :newkey  => 2 },      :renamenx => { :newkey  => 2 },
          :getbit      => { :offset  => 2 },      :setbit   => { :offset  => 2 },
          :setrange    => { :offset  => 2 },      :evalsha  => { :sha     => 1 },
          :getrange    => { :start => 2, :end       => 3 },
          :zrange      => { :start => 2, :end       => 3 },
          :bitcount    => { :start => 2, :stop      => 3 },
          :lrange      => { :start => 2, :stop      => 3 },
          :zrevrange   => { :start => 2, :stop      => 3 },
          :hincrby     => { :field => 2, :increment => 3 },
          :smove           => { :source    => 1, :destination => 2 },
          :bitop           => { :operation => 1, :destkey     => 2 },
          :hincrbyfloat    => { :field     => 2, :increment   => 3 },
          :zremrangebyrank => { :start     => 2, :stop        => 3 }
        }.freeze

        # The following operations don't require any special handling. For these,
        # we only collect KVKey and KVOp
        #
        # :append, :blpop, :brpop, :decr, :del, :dump, :exists,
        # :hgetall, :hkeys, :hlen, :hvals, :hmset, :incr, :linsert,
        # :llen, :lpop, :lpush, :lpushx, :lrem, :lset, :ltrim,
        # :persist, :pttl, :hscan, :rpop, :rpush, :rpushx, :sadd,
        # :scard, :sismember, :smembers, :strlen, :sort, :spop,
        # :srandmember, :srem, :sscan, :ttl, :type, :zadd, :zcard,
        # :zcount, :zincrby, :zrangebyscore, :zrank, :zrem,
        # :zremrangebyscore, :zrevrank, :zrevrangebyscore, :zscore
        #
        # For the operations in NO_KEY_OPS (above) we only collect
        # KVOp (no KVKey)

        def self.included(klass)
          # call_pipelined is alias of call in redisclient middlewares
          SolarWindsAPM::Util.method_alias(klass, :call, ::RedisClient)
          SolarWindsAPM::Util.method_alias(klass, :call_pipelined, ::RedisClient)
        end

        # Given any Redis operation command array, this method
        # extracts the Key/Values to report to the SolarWinds         # dashboard.
        #
        # @param command [Array] the Redis operation array
        # @param r [Return] the return value from the operation
        # @return [Hash] the Key/Values to report
        def extract_trace_details(command, r, config)
          SolarWindsAPM.logger.debug "extract_trace_details command => #{command.inspect}"
          kvs = {}
          op = command.first
          op = op.to_sym

          kvs[:KVOp] = command[0]
          kvs[:RemoteHost] = config.host
          unless NO_KEY_OPS.include?(op) || op == :del && command[1..-1].flatten.count > 1
            if command[1].is_a?(Array)
              kvs[:KVKey] = command[1].first
            else
              kvs[:KVKey] = command[1]
            end
          end

          if KV_COLLECT_MAP[op]
            # Extract KVs from command for this op
            KV_COLLECT_MAP[op].each { |k, v| kvs[k] = command[v] }
          else
            # This case statement handle special cases not handled
            # by KV_COLLECT_MAP
            case op
            when :set
              if command.count > 3
                if command[3].is_a?(Hash)
                  options = command[3]
                  kvs[:ex] = options[:ex] if options.key?(:ex)
                  kvs[:px] = options[:px] if options.key?(:px)
                  kvs[:nx] = options[:nx] if options.key?(:nx)
                  kvs[:xx] = options[:xx] if options.key?(:xx)
                else
                  options = command[3..-1]
                  until (opts = options.shift(2)).empty?
                    case opts[0]
                    when 'EX' then; kvs[:ex] = opts[1]
                    when 'PX' then; kvs[:px] = opts[1]
                    when 'NX' then; kvs[:nx] = opts[1]
                    when 'XX' then; kvs[:xx] = opts[1]
                    end
                  end
                end
              end

            when :get
              kvs[:KVHit] = r.nil? ? 0 : 1

            when :hdel, :hexists, :hget, :hset, :hsetnx
              kvs[:field] = command[2] unless (command[2] && command[3]) # replace the idiom of command[2].is_a?(Array)
              if op == :hget
                kvs[:KVHit] = r.nil? ? 0 : 1
              end

            when :eval
              if command[1].length > 1024
                kvs[:Script] = command[1][0..1023] + '(...snip...)'
              else
                kvs[:Script] = command[1]
              end

            when :script
              kvs[:subcommand] = command[1]
              kvs[:Backtrace] = SolarWindsAPM::API.backtrace if SolarWindsAPM::Config[:redis][:collect_backtraces]
              if command[1] == 'load'
                if command[1].length > 1024
                  kvs[:Script] = command[2][0..1023] + '(...snip...)'
                else
                  kvs[:Script] = command[2]
                end
              elsif command[1] == "exists"
                if command[2].is_a?(Array)
                  kvs[:KVKey] = command[2].inspect
                else
                  kvs[:KVKey] = command[2]
                end
              end

            when :mget
              if command[1].is_a?(Array)
                kvs[:KVKeyCount] = command[1].count
              else
                kvs[:KVKeyCount] = command.count - 1
              end
              values = r.select { |i| i }
              kvs[:KVHitCount] = values.count

            when :hmget
              kvs[:KVKeyCount] = command.count - 2
              values = r.select { |i| i }
              kvs[:KVHitCount] = values.count

            when :mset, :msetnx
              if command[1].is_a?(Array)
                kvs[:KVKeyCount] = command[1].count / 2
              else
                kvs[:KVKeyCount] = (command.count - 1) / 2
              end
            end # case op
          end # if KV_COLLECT_MAP[op]
          # turn every string into number
          # kvs.each do |k,v|
          #   kvs[k] = v.to_i if v.is_a(String)
          # end
        rescue StandardError => e
          SolarWindsAPM.logger.debug "[solarwinds_apm/redis] Error collecting redis KVs: #{e.message}"
          SolarWindsAPM.logger.debug e.backtrace.join('\n')
        ensure
          return kvs
        end

        # Extracts the Key/Values to report from a pipelined
        # call to the SolarWinds dashboard.
        #
        # @param pipeline [Redis::Pipeline] the Redis pipeline instance
        # @return [Hash] the Key/Values to report
        def extract_pipeline_details(commands, config)
          SolarWindsAPM.logger.debug "extract_pipeline_details command => #{commands.inspect}"
          kvs = {}

          kvs[:RemoteHost] = config.host
          kvs[:Backtrace] = SolarWindsAPM::API.backtrace if SolarWindsAPM::Config[:redis][:collect_backtraces]

          command_count = commands.count
          kvs[:KVOpCount] = command_count

          kvs[:KVOp] = if commands.first == :multi
            :multi
          else
            :pipeline
          end

          # Report pipelined operations  if the number
          # of ops is reasonable
          if command_count < 12
            ops = []
            commands.each do |c|
              ops << c.first
            end
            kvs[:KVOps] = ops.join(', ')
          end
        rescue StandardError => e
          SolarWindsAPM.logger.debug "[solarwinds_apm/debug] Error extracting pipelined commands: #{e.message}"
          SolarWindsAPM.logger.debug e.backtrace
        ensure
          return kvs
        end

        #
        # The wrapper method for RedisClient.call.  Here
        # (when tracing) we capture KVs to report and pass
        # the call along
        #
        def call_with_sw_apm(command, config, &block)
          SolarWindsAPM.logger.debug "call_with_sw_apm command => #{command.inspect}"
          if SolarWindsAPM.tracing?
            SolarWindsAPM::API.log_entry(:redis, {})

            begin
              r = call_without_sw_apm(command, config, &block)
              report_kvs = extract_trace_details(command, r, config)
              SolarWindsAPM.logger.debug "call_with_sw_apm command => #{report_kvs.inspect}"
              r
            rescue StandardError => e
              SolarWindsAPM::API.log_exception(:redis, e)
              raise
            ensure
              SolarWindsAPM::API.log_exit(:redis, report_kvs)
            end

          else
            call_without_sw_apm(command, config, &block)
          end
        end

        #
        # The wrapper method for RedisClient.call_pipeline.  Here
        # (when tracing) we capture KVs to report and pass the call along
        # 5.0.0 + removed the deprecated pipelined and multi signature. Commands now MUST be called on the block argument, not the original redis instance
        def call_pipelined_with_sw_apm(commands, config, &block)
          SolarWindsAPM.logger.debug "call_pipelined_with_sw_apm command => #{commands.inspect}"
          if SolarWindsAPM.tracing?
            # Fall back to the raw tracing API so we can pass KVs
            # back on exit (a limitation of the SolarWindsAPM::API.trace
            # block method)  This removes the need for an info
            # event to send additonal KVs
            SolarWindsAPM::API.log_entry(:redis, {})
            report_kvs = extract_pipeline_details(commands, config)
            begin
              call_pipelined_without_sw_apm(commands, config, &block)
            rescue StandardError => e
              SolarWindsAPM::API.log_exception(:redis, e)
              raise
            ensure
              SolarWindsAPM::API.log_exit(:redis, report_kvs)
            end
          else
            call_pipelined_without_sw_apm(commands, config, &block)
          end
        end
      end
    end
  end
end

if SolarWindsAPM::Config[:redis][:enabled]
  if defined?(::RedisClient)
    SolarWindsAPM.logger.info "[solarwinds_apm/loading] Instrumenting redis #{Redis::VERSION}" if SolarWindsAPM::Config[:verbose]
    ::RedisClient.register(SolarWindsAPM::Inst::Redis::Client)
  end
end
