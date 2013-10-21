# Copyright (c) 2013 AppNeta, Inc.
# All rights reserved.

module Oboe
  module Ruby
    def self.initialize
      Oboe::Loading.load_access_key
      Oboe::Inst.load_instrumentation
    end
  end
end
