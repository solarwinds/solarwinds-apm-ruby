# Copyright (c) 2015 AppNeta, Inc.
# All rights reserved.

require 'rack/handler/puma'
require 'traceview/inst/rack'

TraceView.logger.info "[oboe/info] Starting background utility rack app on localhost:8101."

Thread.new do
  app = Rack::Builder.new {
    use TraceView::Rack
    run Proc.new { |env|
      [200, {"Content-Type" => "text/html"}, ['Hello TraceView!']]
    }
  }

  Rack::Handler::Puma.run(app, {:Host => '127.0.0.1', :Port => 8101})
end

# Allow Thin to boot.
sleep(2)

