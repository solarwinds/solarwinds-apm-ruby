# Copyright (c) 2015 AppNeta, Inc.
# All rights reserved.

class RemoteCallWorkerJob
  include Sidekiq::Worker

  def perform(*args)
    # Make some random Dalli (memcache) calls and top it
    # off with an excon call to the background rack webserver.
    @dc = Dalli::Client.new
    @dc.get(rand(10).to_s)
    Excon.get('http://127.0.0.1:8101/')
    @dc.get(rand(10).to_s)
    @dc.get(rand(10).to_s)
    @dc.get_multi([:one, :two, :three, :four, :five, :six])
  end
end
