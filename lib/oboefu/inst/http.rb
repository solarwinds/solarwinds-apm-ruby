require 'net/http'

module Net
  class HTTP
    alias clean_request request

    define_method(:request) do |*args|
      Oboe::Inst.trace_layer_block_ss('http', :request, *args) do
        opts = {}

        if args.length and args[0]
          req = args[0]
          req['X-Trace'] = Oboe::Context.toString()

          opts['IsService'] = 1
          opts['ServiceArg'] = req.path
          opts['RemoteProtocol'] = 'http'
          opts['RemoteHost'] = addr_port
          opts['Method'] = req.method
        end

        response = send(:clean_request, *args)

        xtrace = response.get_fields('X-Trace')
        Oboe::Context.fromString(xtrace[0]) if xtrace and xtrace.size

        [response, opts]
      end
    end
  end
end
