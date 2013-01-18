module Oboe
  module Inst
    def self.load_instrumentation
      # Load the general instrumentation
      pattern = File.join(File.dirname(__FILE__), 'inst', '*.rb')
      Dir.glob(pattern) do |f|
        begin
          require f
        rescue => e
          $stderr.puts "[oboe/loading] Error loading insrumentation file '#{f}' : #{e}"
        end
      end
    end
  end
end
