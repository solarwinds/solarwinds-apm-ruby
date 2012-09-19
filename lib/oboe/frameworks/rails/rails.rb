
module Oboe
  module Inst
    module Rails

      module Helpers
        extend ActiveSupport::Concern

        def tracelytics_rum_header
          render :file => File.dirname(__FILE__) + '/helpers/rum/rum_header', :formats => [:js]
        end

        def tracelytics_rum_footer
          render :file => File.dirname(__FILE__) + '/helpers/rum/rum_footer', :formats => [:js]
        end
      end # Helpers

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

      def self.include_helpers
        # TBD: This would make the helpers available to controllers which is occasionally desired.
        # ActiveSupport.on_load(:action_controller) do
        #   include Oboe::Inst::Rails::Helpers
        # end
        
        ActiveSupport.on_load(:action_view) do
          include Oboe::Inst::Rails::Helpers
        end
      end

    end # Rails
  end # Inst
end # Oboe

if defined?(::Rails)
  if ::Rails::VERSION::MAJOR > 2
    module Oboe
      class Railtie < ::Rails::Railtie
        
        initializer 'oboe.helpers' do
          Oboe::Inst::Rails.include_helpers        
        end

        config.after_initialize do
          Oboe::Inst::Rails.load_instrumentation
        end
      end
    end
    Oboe::Inst::Rails.load_initializer
  else
    Oboe::Inst::Rails.load_initializer
    Oboe::Inst::Rails.load_instrumentation
    Oboe::Inst::Rails::Helpers.include_helpers        
  end
end

