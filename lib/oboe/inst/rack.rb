require 'appoptics_apm/inst/rack'

module Oboe
  class Rack < AppOpticsAPM::Rack
    # This simply makes Oboe::Rack available (and a clone of AppOpticsAPM::Rack) for
    # backward compatibility
    #
    # Provided for pre-existing apps (sinatra, padrino, grape etc..) that may still
    # call `use Oboe::Rack`
  end
end
