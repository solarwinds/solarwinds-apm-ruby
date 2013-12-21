# Copyright (c) 2013 AppNeta, Inc.
# All rights reserved.

if defined?(::Sinatra)
  require 'oboe/inst/rack'

  Sinatra::Base.use Oboe::Rack
end
