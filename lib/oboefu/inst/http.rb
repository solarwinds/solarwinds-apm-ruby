# Copyright (c) 2012 by Tracelytics, Inc.
# All rights reserved.

require 'net/http'

Net::HTTP.class_eval do
  def request_with_oboe(*args, &block)
    unless started?
      return request_without_oboe(*args, &block)
    end

    Oboe::API.trace('net-http') do
        opts = {}
        if args.length and args[0]
          req = args[0]
          req['X-Trace'] = Oboe::Context.toString()

          opts['IsService'] = 1
          opts['RemoteProtocol'] = use_ssl? ? 'HTTPS' : 'HTTP'
          opts['RemoteHost'] = addr_port
          opts['ServiceArg'] = req.path
          opts['Method'] = req.method
        end

        Oboe::API.log('net-http', 'info', opts)
        resp = request_without_oboe(*args, &block)

        xtrace = resp.get_fields('X-Trace')
        if xtrace and xtrace.size and Oboe::Config.tracing?
          Oboe::Context.fromString(xtrace[0])
        end
        next resp
    end
  end

  alias request_without_oboe request
  alias request request_with_oboe

  puts "[oboe_fu/loading] Instrumenting net/http" if Oboe::Config[:verbose]
end
