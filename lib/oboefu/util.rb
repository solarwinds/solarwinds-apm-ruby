module OboeFu
  def self.require_instrumentation
    require 'oboe'
    require 'oboe_fu_util'

    pattern = File.join(File.dirname(__FILE__), 'lib', 'inst', '*.rb')
    Dir.glob(pattern) do |f|
      begin
        puts "[oboe_fu/loading] Instrumentation '#{f}'"
        require f
      rescue => e
        $stderr.puts "[oboe_fu/loading] Error loading insrumentation file '#{f}' : #{e}"
      end
    end
  end
end
