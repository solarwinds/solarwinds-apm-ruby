# Copyright (c) 2015 AppNeta, Inc.
# All rights reserved.

Oboe.logger.info "[oboe/info] Starting background utility rack app on localhost:8101."

Thread.new do
  app = Rack::Builder.new {
    use Oboe::Rack
    run Proc.new { |env|
      [200, {"Content-Type" => "text/html"}, ['Hello, world!']]
    }
  }

  Rack::Handler::Thin.run(app, :Port => 8101)
end

# Allow Thin to boot.
sleep(2)

