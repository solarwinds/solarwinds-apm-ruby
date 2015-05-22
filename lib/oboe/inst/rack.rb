require 'traceview/inst/rack'

module Oboe
  class Rack < TraceView::Rack
    # This simply makes Oboe::Rack available (and a clone of TraceView::Rack)
    #
    # Provided for pre-existing apps (sinatra, padrino, grape etc..) that may still
    # call `use Oboe::Rack`
  end
end
