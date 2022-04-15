# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

class ResqueRemoteCallWorkerJob
  @queue = :critical

  def self.perform(*args)
    # Make a random Dalli (memcache) call and top it
    # off with a call to the background rack webserver
    @dc = Dalli::Client.new("#{ENV['MEMCACHED_SERVER'] || 'localhost'}:11211")
    @dc.get(rand(10).to_s)

    uri = URI('http://127.0.0.1:8110')
    Net::HTTP.get(uri)
  end

end
