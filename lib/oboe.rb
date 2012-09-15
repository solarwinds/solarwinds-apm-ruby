# Copyright (c) 2012 by Tracelytics, Inc.
# All rights reserved.

require 'oboe/loading'

if defined?(Rails) and Rails::VERSION::MAJOR == 3
  module Oboe
    class Railtie < Rails::Railtie
      initializer "oboe.start" do |app|
        Oboe::Loading.require_instrumentation
      end
    end
  end
else
  Oboe::Loading.require_instrumentation
end
