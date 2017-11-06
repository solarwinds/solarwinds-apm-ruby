require 'appoptics/inst/rack'

module Oboe
  class Rack < AppOptics::Rack
    # This simply makes Oboe::Rack available (and a clone of AppOptics::Rack) for
    # backward compatibility
    #
    # Provided for pre-existing apps (sinatra, padrino, grape etc..) that may still
    # call `use Oboe::Rack`
  end
end
