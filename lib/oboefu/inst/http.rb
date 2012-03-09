# Copyright (c) 2012 by Tracelytics, Inc.
# All rights reserved.

=begin
require 'net/http'

module Net
  class HTTP
    alias clean_request request

    define_method(:request) do |*args|
      unless started?
        return send(:clean_request, *args)
      end

      Oboe::Inst.trace_layer_block_ss('http', self, 'request', *args) do
        opts = {}

        if args.length and args[0]
          req = args[0]
          req['X-Trace'] = Oboe::Context.toString()

          opts['IsService'] = 1
          opts['RemoteProtocol'] = 'http'
          opts['RemoteHost'] = addr_port
          opts['Method'] = req.method
        end

        resp = self.send(:clean_request, *args)

        xtrace = resp.get_fields('X-Trace')
        Oboe::Context.fromString(xtrace[0]) if xtrace and xtrace.size

        next [resp, opts]
      end
    end
  end
end
=end
