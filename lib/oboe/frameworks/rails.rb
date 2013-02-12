module Oboe
  module Rails
    module Helpers
      extend ActiveSupport::Concern if ::Rails::VERSION::MAJOR > 2

      def oboe_rum_header
        begin
          return unless Oboe::Config.has_key?(:rum_id)
          if Oboe.tracing?
            if request.xhr?
              header_tmpl = File.read(File.dirname(__FILE__) + '/rails/helpers/rum/rum_ajax_header.js.erb')
            else
              header_tmpl = File.read(File.dirname(__FILE__) + '/rails/helpers/rum/rum_header.js.erb')
            end
            return raw(ERB.new(header_tmpl).result)
          end
        rescue Exception => e  
          logger.warn "oboe_rum_header: #{e.message}." if defined?(logger)
          return ""
        end
      end
      
      def oboe_rum_footer
        begin
          return unless Oboe::Config.has_key?(:rum_id)
          if Oboe.tracing?
            # Even though the footer template is named xxxx.erb, there are no ERB tags in it so we'll
            # skip that step for now
            footer_tmpl = File.read(File.dirname(__FILE__) + '/rails/helpers/rum/rum_footer.js.erb')
            return raw(footer_tmpl)
          end
        rescue Exception => e
          logger.warn "oboe_rum_footer: #{e.message}." if defined?(logger)
          return ""
        end
      end
    end # Helpers
      
    def self.load_initializer
      # Force load the tracelytics Rails initializer if there is one
      # Prefer oboe.rb but give priority to tracelytics.rb if it exists
      if ::Rails::VERSION::MAJOR > 2
        rails_root = "#{::Rails.root.to_s}"
      else
        rails_root = "#{RAILS_ROOT}"
      end

      if File.exists?("#{rails_root}/config/initializers/tracelytics.rb")
        tr_initializer = "#{rails_root}/config/initializers/tracelytics.rb"
      else 
        tr_initializer = "#{rails_root}/config/initializers/oboe.rb"
      end
      require tr_initializer if File.exists?(tr_initializer)
    end

    def self.load_instrumentation
      # Load the Rails specific instrumentation
      pattern = File.join(File.dirname(__FILE__), 'rails/inst', '*.rb')
      Dir.glob(pattern) do |f|
        begin
          require f
        rescue => e
          $stderr.puts "[oboe/loading] Error loading rails insrumentation file '#{f}' : #{e}"
        end
      end
      
      if ::Rails::VERSION::MAJOR > 2
        puts "Tracelytics oboe gem #{Gem.loaded_specs['oboe'].version.to_s} successfully loaded."
      else
        puts "Tracelytics oboe gem #{Oboe::Version::STRING} successfully loaded." 
      end
    end

    def self.include_helpers
      # TBD: This would make the helpers available to controllers which is occasionally desired.
      # ActiveSupport.on_load(:action_controller) do
      #   include Oboe::Rails::Helpers
      # end
      if ::Rails::VERSION::MAJOR > 2
        ActiveSupport.on_load(:action_view) do
          include Oboe::Rails::Helpers
        end
      else
        ActionView::Base.send :include, Oboe::Rails::Helpers
      end
    end

  end # Rails
end # Oboe

if defined?(::Rails)
  require 'oboe/inst/rack'

  if ::Rails::VERSION::MAJOR > 2
    module Oboe
      class Railtie < ::Rails::Railtie
        
        initializer 'oboe.helpers' do
          Oboe::Rails.include_helpers        
        end

        initializer 'oboe.rack' do |app|
          puts "[oboe/loading] Instrumenting rack" if Oboe::Config[:verbose]
          app.config.middleware.insert 0, "Oboe::Rack"
        end

        config.after_initialize do
          Oboe::Loading.load_access_key
          Oboe::Inst.load_instrumentation
          Oboe::Rails.load_instrumentation
        end
      end
    end
  else
    Oboe::Rails.load_initializer
    Oboe::Loading.load_access_key

    puts "[oboe/loading] Instrumenting rack" if Oboe::Config[:verbose]
    Rails.configuration.middleware.insert 0, "Oboe::Rack"

    Oboe::Inst.load_instrumentation
    Oboe::Rails.load_instrumentation
    Oboe::Rails.include_helpers
    
  end
end

