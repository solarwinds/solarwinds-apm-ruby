# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

# This is a Rack application that is booted in a background
# thread and listens on port 8101.
#
require 'rack/handler/puma'
require 'appoptics_apm/inst/rack'

AppOpticsAPM.logger.info "[appoptics_apm/info] Starting background utility rack app on localhost:8101."

Thread.new do
  app = Rack::Builder.new {
    use AppOpticsAPM::Rack
    map "/" do
      run Proc.new { [200, {"Content-Type" => "text/html"}, ['Hello AppOpticsAPM!']] }
    end

    map "/redirectme" do
      run Proc.new { [301, {"Location" => "/", "Content-Type" => "text/html"}, ['']] }
    end
  }

  Rack::Handler::Puma.run(app, {:Host => '127.0.0.1', :Port => 8101})
end

AppOpticsAPM.logger.info "[appoptics_apm/info] Starting UNINSTRUMENTED background utility rack app on localhost:8110."

Thread.new do
  app = Rack::Builder.new {
    map "/" do
      run Proc.new { [200, {"Content-Type" => "text/html"}, ['Hello AppOpticsAPM!']] }
    end

    map "/redirectme" do
      run Proc.new { [301, {"Location" => "/", "Content-Type" => "text/html"}, ['']] }
    end
  }

  Rack::Handler::Puma.run(app, {:Host => '127.0.0.1', :Port => 8110})
end

# Allow Thin to boot.
sleep(2)

