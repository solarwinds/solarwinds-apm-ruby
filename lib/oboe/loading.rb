# Copyright (c) 2012 by Tracelytics, Inc.
# All rights reserved.

require "base64url"
require 'digest/sha1'

module Oboe
  module Loading

    def self.load_access_key
      config_file = '/etc/tracelytics.conf'
      return unless File.exists?(config_file)
      
      begin
        File.open(config_file).each do |line|
          if line =~ /^tracelyzer.access_key=/ or line =~ /^access_key/
            bits = line.split(/=/)
            Oboe::Config[:access_key] = bits[1].strip
            Oboe::Config[:rum_id] = Base64URL.encode(Digest::SHA1.hexdigest("RUM" + Oboe::Config[:access_key]))
            break
          end
        end
      rescue
        puts "Having trouble parsing #{config_file}..."
      end
    end

    def self.require_api
      pattern = File.join(File.dirname(__FILE__), 'api', '*.rb')
      Dir.glob(pattern) do |f|
        require f
      end
      require 'oboe/api'

      begin
        Oboe::API.extend_with_tracing
      rescue LoadError => e
        Oboe::API.extend_with_noop
      end
      
      require 'oboe/config'
    end

    def self.load_framework_instrumentation
      pattern = File.join(File.dirname(__FILE__), 'frameworks/*/', '*.rb')
      Dir.glob(pattern) do |f|
        begin
          require f
        rescue => e
          $stderr.puts "[oboe/loading] Error loading framework file '#{f}' : #{e}"
        end
      end

    end
  end
end

Oboe::Loading.require_api
Oboe::Loading.load_access_key
Oboe::Loading.load_framework_instrumentation

