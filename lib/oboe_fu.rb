# Copyright (c) 2012 by Tracelytics, Inc.
# All rights reserved.

require 'oboefu/loading'

if defined?(Rails) and Rails::VERSION::MAJOR == 3
  module OboeFu
    class Railtie < Rails::Railtie
      initializer "oboe_fu.start" do |app|
        # Force load the tracelytics user initializer if there is one
        tr_initializer = "#{Rails.root}/config/initializers/tracelytics.rb"
        require tr_initializer if File.exists?(tr_initializer)

        OboeFu::Loading.require_instrumentation
      end
    end
  end
else
  OboeFu::Loading.require_instrumentation
end
