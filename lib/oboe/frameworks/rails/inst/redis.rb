if defined?(Redis::Client)
  Redis::Client.class_eval do
    puts "[oboe/loading] Instrumenting redis" if Oboe::Config[:verbose]

    alias :old_process :process

    def process(*args, &blk)
      opts = {}

      begin
        list = args.flatten
        opts[:KVOp] = list.first
      rescue
      end

      Oboe::API.trace('redis', opts || {}) do
        old_process(*args, &blk)
      end
    end
  end
end
