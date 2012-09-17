# Copyright (c) 2012 by Tracelytics, Inc.
# All rights reserved.
          
module Oboe
  class Railtie < Rails::Railtie
    initializer "oboe.start" do |app|
      Oboe::Loading.require_api
      Oboe::Loading.instrument_rails if defined?(Rails)
    end
  end
end

begin
  require 'oboe_metal.so'
  require 'rbconfig'
  require 'oboe_metal'
  require 'oboe/loading'

rescue LoadError
  puts "Unsupported Tracelytics environment (no libs).  Going No-op."
end
