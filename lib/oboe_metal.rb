# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'thread'

# Disable docs and Camelcase warns since we're implementing
# an interface here.  See OboeBase for details.
# rubocop:disable Style/Documentation, Style/MethodName
module AppOptics
  extend AppOpticsBase
  include Oboe_metal

  class Reporter
    class << self
      ##
      # start
      #
      # Start the AppOptics Reporter
      #
      def start
        return unless AppOptics.loaded

        begin
          protocol = ENV.key?('APPOPTICS_GEM_TEST') ? 'file' :
                       ENV['TRACELYTICS_REPORTER'] || 'ssl'

          case protocol
          when 'file'
            options = "file=#{TRACE_FILE}"
          when 'udp'
            options = "addr=#{AppOptics::Config[:reporter_host]},port=#{AppOptics::Config[:reporter_port]}"
          else
            if ENV['APPOPTICS_SERVICE_KEY'].to_s == ''
              AppOptics.logger.warn "[appoptics/warn] APPOPTICS_SERVICE_KEY not set. Cannot submit data."
              AppOptics.loaded = false
              return
            end
            # ssl reporter requires the service key passed in as arg "cid"
            options = "cid=#{ENV['APPOPTICS_SERVICE_KEY']}"
          end

          AppOptics.reporter = Oboe_metal::Reporter.new(protocol, options)

          # Only report __Init from here if we are not instrumenting a framework.
          # Otherwise, frameworks will handle reporting __Init after full initialization
          unless defined?(::Rails) || defined?(::Sinatra) || defined?(::Padrino) || defined?(::Grape)
            AppOptics::API.report_init
          end

        rescue => e
          $stderr.puts e.message
          raise
        end
      end
      alias :restart :start

      ##
      # sendReport
      #
      # Send the report for the given event
      #
      def sendReport(evt)
        AppOptics.reporter.sendReport(evt)
      end

      ##
      # sendStatus
      #
      # Send the report for the given event
      #
      def sendStatus(evt, context = nil)
        AppOptics.reporter.sendStatus(evt, context)
      end

      ##
      # clear_all_traces
      #
      # Truncates the trace output file to zero
      #
      def clear_all_traces
        File.truncate(TRACE_FILE, 0)
      end

      ##
      # get_all_traces
      #
      # Retrieves all traces written to the trace file
      #
      def get_all_traces
        io = File.open(TRACE_FILE, 'r')
        contents = io.readlines(nil)

        return contents if contents.empty?

        traces = []

        #
        # We use Gem.loaded_spec because older versions of the bson
        # gem didn't even have a version embedded in the gem.  If the
        # gem isn't in the bundle, it should rightfully error out
        # anyways.
        #
        if Gem.loaded_specs['bson'].version.to_s < '4.0'
          s = StringIO.new(contents[0])

          until s.eof?
            traces << if ::BSON.respond_to? :read_bson_document
                        BSON.read_bson_document(s)
                      else
                        BSON::Document.from_bson(s)
                      end
          end
        else
          bbb = BSON::ByteBuffer.new(contents[0])
          until bbb.length == 0
            traces << Hash.from_bson(bbb)
          end
        end

        traces
      end
    end
  end

  module EventUtil
    def self.metadataString(evt)
      evt.metadataString
    end
  end

  class << self
    def sample?(opts = {})
      # Return false if no-op mode
      return false unless AppOptics.loaded

      # Assure defaults since SWIG enforces Strings
      layer   = opts[:layer]      ? opts[:layer].to_s.strip.freeze : APPOPTICS_STR_BLANK
      xtrace  = opts[:xtrace]     ? opts[:xtrace].to_s.strip       : APPOPTICS_STR_BLANK

      rv = AppOptics::Context.sampleRequest(layer, xtrace)

      if rv == 0
        AppOptics.sample_rate = -1
        AppOptics.sample_source = -1
        false
      else
        # liboboe version > 1.3.1 returning a bit masked integer with SampleRate and
        # source embedded
        AppOptics.sample_rate = (rv & SAMPLE_RATE_MASK)
        AppOptics.sample_source = (rv & SAMPLE_SOURCE_MASK) >> 24
        true
      end
    rescue StandardError => e
      AppOptics.logger.debug "[oboe/error] sample? error: #{e.inspect}"
      false
    end

    def set_tracing_mode(mode)
      return unless AppOptics.loaded

      value = mode.to_sym

      case value
      when :never
        AppOptics::Context.setTracingMode(OBOE_TRACE_NEVER)

      when :always
        AppOptics::Context.setTracingMode(OBOE_TRACE_ALWAYS)

      else
        AppOptics.logger.fatal "[oboe/error] Invalid tracing mode set: #{mode}"
        AppOptics::Context.setTracingMode(OBOE_TRACE_NEVER)
      end
    end

    def set_sample_rate(rate)
      return unless AppOptics.loaded

      # Update liboboe with the new SampleRate value
      AppOptics::Context.setDefaultSampleRate(rate.to_i)
    end
  end
end
# rubocop:enable Style/Documentation

AppOptics.loaded = true
AppOptics.config_lock = Mutex.new
