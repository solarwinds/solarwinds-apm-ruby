# Copyright (c) 2012 by Tracelytics, Inc.
# All rights reserved.
require 'oboefu/util'

if defined?(Rails) and Rails::VERSION::MAJOR == 3
  module OboeFu
    class Railtie < Rails::Railtie
      initializer "oboe_fu.start" do |app|
        OboeFu.require_instrumentation
      end
    end
  end
else
  OboeFu.require_instrumentation
end
