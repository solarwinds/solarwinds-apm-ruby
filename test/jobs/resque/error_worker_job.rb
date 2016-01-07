# Copyright (c) 2015 AppNeta, Inc.
# All rights reserved.

class ResqueErrorWorkerJob
  @queue = :critical

  def self.perform(*args)
    raise "This is a worker error yeah!"
  end
end
