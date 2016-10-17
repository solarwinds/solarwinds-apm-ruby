# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

# This is a Rack application that is booted in a background
# thread and listens on port 8101.
#
require 'rack/handler/puma'
require 'traceview/inst/rack'

TraceView.logger.info "[traceview/info] Starting background utility rack app on localhost:8101."

Thread.new do
  app = Rack::Builder.new {
    use TraceView::Rack
    map "/" do
      run Proc.new { |env|
        [200, {"Content-Type" => "text/html"}, ['Hello TraceView!']]
      }
    end

    map "/redirectme" do
      run Proc.new { |env|
        [301, {"Location" => "/", "Content-Type" => "text/html"}, ['']]
      }
    end
  }

  Rack::Handler::Puma.run(app, {:Host => '127.0.0.1', :Port => 8101})
end

# Allow Thin to boot.
sleep(2)

