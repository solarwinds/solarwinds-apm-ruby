# Copyright (c) 2012 by Tracelytics, Inc.
# All rights reserved.

require 'net/http'

Net::HTTP.class_eval do
  def instrumented_request(*args, &block)
    unless started?
      return clean_request(*args, &block)
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

        resp = clean_request(*args, &block)

        xtrace = resp.get_fields('X-Trace')
        Oboe::Context.fromString(xtrace[0]) if xtrace and xtrace.size

        next [resp, opts]
    end
  end

  alias clean_request request
  alias request instrumented_request
end
