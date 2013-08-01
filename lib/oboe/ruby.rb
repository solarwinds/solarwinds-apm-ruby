module Oboe
  module Ruby
    def self.initialize
      Oboe::Loading.load_access_key
      Oboe::Loading.set_tracing_mode
      Oboe::Inst.load_instrumentation
    end
  end
end
