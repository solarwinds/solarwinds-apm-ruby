
module Oboe
  module Inst
    module Rails
      def self.load_initializer
        # Force load the tracelytics Rails initializer if there is one
        tr_initializer = "#{::Rails.root}/config/initializers/tracelytics.rb"
        require tr_initializer if File.exists?(tr_initializer)
      end

      def self.load_instrumentation
        pattern = File.join(File.dirname(__FILE__), 'inst', '*.rb')
        Dir.glob(pattern) do |f|
          begin
            require f
          rescue => e
            $stderr.puts "[oboe/loading] Error loading rails insrumentation file '#{f}' : #{e}"
          end
        end
      end
    end
  end
end

if defined?(::Rails)
  if ::Rails::VERSION::MAJOR > 2
    module Oboe
      class Railtie < ::Rails::Railtie
        config.after_initialize do
          Oboe::Inst::Rails.load_instrumentation
        end
      end
    end
    Oboe::Inst::Rails.load_initializer
  else
    Oboe::Inst::Rails.load_initializer
    Oboe::Inst::Rails.load_instrumentation
  end
end

