# Copyright (c) 2013 AppNeta, Inc.
# All rights reserved.

require 'digest/sha1'

module Oboe
  module Util
    ##
    # This module is used solely for RUM ID calculation
    #
    module Base64URL
      module_function

      def encode(bin)
        c = [bin].pack('m0').gsub(/\=+\Z/, '').tr('+/', '-_').rstrip
        m = c.size % 4
        c += '=' * (4 - m) if m != 0
        c
      end

      def decode(bin)
        m = bin.size % 4
        bin += '=' * (4 - m) if m != 0
        bin.tr('-_', '+/').unpack('m0').first
      end
    end
  end

  ##
  # This module houses all of the loading functionality for the oboe gem.  
  #
  # Note that this does not necessarily _have_ to include initialization routines 
  # (although it can).
  #
  # Actual initialization is often separated out as it can be dependent on on the state
  # of the stack boot process.  e.g. code requiring that initializers, frameworks or 
  # instrumented libraries are already loaded...
  #
  module Loading
    ##
    # Load the TraceView access key (either from system configuration file
    # or environment variable) and calculate internal RUM ID
    #
    def self.load_access_key
      begin
        if ENV.has_key?('TRACEVIEW_CUUID')
          # Preferably get access key from environment (e.g. Heroku)
          Oboe::Config[:access_key] = ENV['TRACEVIEW_CUUID']
          Oboe::Config[:rum_id] = Oboe::Util::Base64URL.encode(Digest::SHA1.digest("RUM" + Oboe::Config[:access_key]))
        else
          # ..else read from system-wide configuration file
          if Oboe::Config.access_key.empty?
            config_file = '/etc/tracelytics.conf'
            return unless File.exists?(config_file)
            
            File.open(config_file).each do |line|
              if line =~ /^tracelyzer.access_key=/ or line =~ /^access_key/
                bits = line.split(/=/)
                Oboe::Config[:access_key] = bits[1].strip
                Oboe::Config[:rum_id] = Oboe::Util::Base64URL.encode(Digest::SHA1.digest("RUM" + Oboe::Config[:access_key]))
                break
              end
            end
          end
        end
      rescue Exception => e
        Oboe.logger.error "Trouble obtaining access_key and rum_id: #{e.inspect}"
      end
    end

    ##
    # Load the oboe tracing API
    # 
    def self.require_api
      pattern = File.join(File.dirname(__FILE__), 'api', '*.rb')
      Dir.glob(pattern) do |f|
        require f
      end
      require 'oboe/api'

      begin
        Oboe::API.extend_with_tracing
      rescue LoadError => e
        Oboe.logger.fatal "[oboe/error] Couldn't load oboe api."
      end
    end
  end
end

Oboe::Loading.require_api

# Auto-start the Reporter unless we running Unicorn on Heroku
# In that case, we start the reporters after fork
unless defined?(::Unicorn) and ENV.has_key?('TRACEVIEW_URL')
  Oboe::Reporter.start
end

