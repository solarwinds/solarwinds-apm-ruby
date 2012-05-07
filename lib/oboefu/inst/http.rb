# Copyright (c) 2012 by Tracelytics, Inc.
# All rights reserved.

=begin
require 'net/http'

Net::HTTP.class_eval do
  def request_with_oboe(*args, &block)
    unless started?
      return clean_request(*args, &block)
    end

    Oboe::API.trace('http') do
        opts = {}
        if args.length and args[0]
          req = args[0]
          req['X-Trace'] = Oboe::Context.toString()

          opts['IsService'] = 1
          opts['RemoteProtocol'] = 'http'
          opts['RemoteHost'] = addr_port
          opts['Method'] = req.method
        end

        resp = request_without_oboe(*args, &block)

        xtrace = resp.get_fields('X-Trace')
        Oboe::Context.fromString(xtrace[0]) if xtrace and xtrace.size
        Oboe::API.log('http', 'info', opts)

        next resp
    end
  end

  alias request_without_oboe request
  alias request request_with_oboe
end
=end
