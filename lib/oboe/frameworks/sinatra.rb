# Copyright (c) 2013 AppNeta, Inc.
# All rights reserved.

module Oboe
  module Sinatra
    module Base
      def self.included(klass)
        ::Oboe::Util.method_alias(klass, :dispatch!, ::Sinatra::Base)
      end

      def dispatch_with_oboe
        if Oboe.tracing?
          report_kvs = {}

          # Fall back to the raw tracing API so we can pass KVs
          # back on exit (a limitation of the Oboe::API.trace
          # block method) This removes the need for an info
          # event to send additonal KVs
          ::Oboe::API.log_entry('sinatra', {})

          begin
            dispatch_without_oboe
          ensure
            ::Oboe::API.log_exit('sinatra', report_kvs)
          end
        else
          dispatch_without_oboe
        end
      end
    end
  end
end

if defined?(::Sinatra)
  require 'oboe/inst/rack'

  Oboe.logger.info "[oboe/loading] Instrumenting Sinatra" if Oboe::Config[:verbose]

  Oboe::Loading.setup_logger
  Oboe::Loading.load_access_key
  Oboe::Inst.load_instrumentation

  ::Sinatra::Base.use Oboe::Rack
  ::Oboe::Util.send_include(::Sinatra::Base, ::Oboe::Sinatra::Base)
end
