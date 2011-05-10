if defined?(Memcached)
  class Memcached
    [:decrement, :get, :increment, :set, :cas, :add, :replace, :prepend, :append, :delete].each do |m|
      next unless method_defined?(m)

      class_eval("alias clean_#{m} #{m}")
      define_method(m) do |*args|
        opts = { :KVOp => m }
        if args.length and args[0].class != Array
            opts[:KVKey] = args[0].to_s if args.length
        end
        Oboe::Inst.trace_agent_block('memcache', opts) do
          send("clean_#{m}", *args) 
        end
      end
    end
  end
end
