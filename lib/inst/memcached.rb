if defined?(Memcached)
  class Memcached
    [:decrement, :get, :increment, :set, :cas, :add, :replace, :prepend, :append, :delete].each do |m|
      next unless method_defined?(m)

      class_eval("alias clean_#{m} #{m}")
      define_method(m) do |*args|
        opts = { :KVOp => m }
        if args.length and args[0].class != Array
            opts[:KVKey] = args[0].to_s
            if defined?(Lib) and defined?(Lib.memcached_server_by_key) \
                    and defined?(@struct) and defined?(is_unix_socket?)
                server_as_array = Lib.memcached_server_by_key(@struct, args[0].to_s)
                if server_as_array.is_a?(Array)
                    server = server_as_array.first
                    if is_unix_socket?(server)
                        opts[:RemoteHost] = "localhost"
                    elsif defined?(server.hostname)
                        opts[:RemoteHost] = server.hostname
                    end
                end
            end
        end
        Oboe::Inst.trace_layer_block('memcache', opts) do
          send("clean_#{m}", *args) 
        end
      end
    end
  end
end
