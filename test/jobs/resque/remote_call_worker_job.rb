# Copyright (c) 2015 AppNeta, Inc.
# All rights reserved.

class ResqueRemoteCallWorkerJob
  @queue = :critical

  def perform(*args)
    # Make some random Dalli (memcache) calls and top it
    # off with an excon call to the background rack webserver.
    @dc = Dalli::Client.new
    @dc.get(rand(10).to_s)
    uri = URI('http://gameface.in/gamers')
    http = Net::HTTP.new(uri.host, uri.port)
    request = Net::HTTP::Get.new(uri.request_uri)
    http.request(request)
    @dc.get(rand(10).to_s)
    @dc.get(rand(10).to_s)
    @dc.get_multi([:one, :two, :three, :four, :five, :six])
  end
end
