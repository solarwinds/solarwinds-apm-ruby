# Copyright (c) 2012 by Tracelytics, Inc.
# All rights reserved.
require 'oboefu/loading'

if defined?(Rails) and Rails::VERSION::MAJOR == 3
  module OboeFu
    class Railtie < Rails::Railtie
      initializer "oboe_fu.start" do |app|
        OboeFu::Loading.require_instrumentation
      end
    end
  end
else
  OboeFu::Loading.require_instrumentation
end
