# Copyright (c) 2013 AppNeta, Inc.
# All rights reserved.

if defined?(::Padrino)
  # This instrumentation is a superset of the Sinatra similar to how Padrino
  # is a superset of Sinatra itself.
  Oboe.logger.info "[oboe/loading] Instrumenting Padrino" if Oboe::Config[:verbose]

  Oboe.logger = ::Padrino.logger if ::Padrino.logger
  Oboe::Loading.load_access_key
  Oboe::Inst.load_instrumentation
end

