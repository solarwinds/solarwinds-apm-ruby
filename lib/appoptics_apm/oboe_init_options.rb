# Copyright (c) 2019 SolarWinds, LLC.
# All rights reserved.

require 'singleton'

module AppOpticsAPM

  class OboeInitOptions
    include Singleton

    attr_reader :reporter, :host

    # TODO decide if these globals are useful when testing
    # OBOE_HOSTNAME_ALIAS = 0
    # OBOE_DEBUG_LEVEL = 1
    # OBOE_LOGFILE = 2
    #
    # OBOE_MAX_TRANSACTIONS = 3
    # OBOE_FLUSH_MAX_WAIT_TIME = 4
    # OBOE_EVENTS_FLUSH_INTERVAL = 5
    # OBOE_EVENTS_FLUSH_BATCH_SIZE = 6
    #
    # OBOE_REPORTER = 7
    # OBOE_COLLECTOR = 8
    # OBOE_SERVICE_KEY = 9
    # OBOE_TRUSTEDPATH = 10
    #
    # OBOE_BUFSIZE = 11
    # OBOE_TRACE_METRICS = 12
    # OBOE_HISTOGRAM_PRECISION = 13
    # OBOE_TOKEN_BUCKET_CAPACITY = 14
    # OBOE_TOKEN_BUCKET_RATE = 15
    # OBOE_FILE_SINGLE = 16

    def initialize
      # optional hostname alias
      @hostname_alias = ENV['APPOPTICS_HOSTNAME_ALIAS'] || AppOpticsAPM::Config[:hostname_alias] || ''
      # level at which log messages will be written to log file (0-6)
      @debug_level = (ENV['APPOPTICS_DEBUG_LEVEL'] || AppOpticsAPM::Config[:debug_level] || 3).to_i
      # file name including path for log file
      # TODO eventually find better way to combine ruby and oboe logs
      @log_file_path = ENV['APPOPTICS_LOGFILE'] || ''
      # maximum number of transaction names to track
      @max_transactions = (ENV['APPOPTICS_MAX_TRANSACTIONS'] || -1).to_i
      # maximum wait time for flushing data before terminating in milli seconds
      @max_flush_wait_time = (ENV['APPOPTICS_FLUSH_MAX_WAIT_TIME'] || -1).to_i
      # events flush timeout in seconds (threshold for batching messages before sending off)
      @events_flush_interval = (ENV['APPOPTICS_EVENTS_FLUSH_INTERVAL'] || -1).to_i
      # events flush batch size in KB (threshold for batching messages before sending off)
      @event_flush_batch_size = (ENV['APPOPTICS_EVENTS_FLUSH_BATCH_SIZE'] || -1).to_i

      # the reporter to be used (ssl, upd, file, null)
      # collector endpoint (reporter=ssl), udp address (reporter=udp), or file path (reporter=file)
      reporter_and_host # sets @reporter and @host

      # the service key
      @service_key = ENV['APPOPTICS_SERVICE_KEY'] || AppOpticsAPM::Config[:service_key] || ''
      # path to the SSL certificate (only for ssl)
      @trusted_path = ENV['APPOPTICS_TRUSTEDPATH'] || ''
      # size of the message buffer
      @buffer_size = (ENV['APPOPTICS_BUFSIZE'] || -1).to_i
      # flag indicating if trace metrics reporting should be enabled (default) or disabled
      @trace_metrics = (ENV['APPOPTICS_TRACE_METRICS'] || -1).to_i
      # the histogram precision (only for ssl)
      @histogram_precision = (ENV['APPOPTICS_HISTOGRAM_PRECISION'] || -1).to_i
      # custom token bucket capacity
      @token_bucket_capacity = (ENV['APPOPTICS_TOKEN_BUCKET_CAPACITY'] || -1).to_i
      # custom token bucket rate
      @token_bucket_rate = (ENV['APPOPTICS_TOKEN_BUCKET_RATE'] || -1).to_i
      # use single files in file reporter for each event
      @file_single = (ENV['APPOPTICS_REPORTER_FILE_SINGLE'].to_s.downcase == 'true') ? 1 : 0
    end

    def re_init # for testing with changed ENV vars
      initialize
    end

    def array_for_oboe
      [
        @hostname_alias,
        @debug_level,
        @log_file_path,
        @max_transactions,
        @max_flush_wait_time,
        @events_flush_interval,
        @event_flush_batch_size,

        @reporter,
        @host,
        @service_key,
        @trusted_path,
        @buffer_size,
        @trace_metrics,
        @histogram_precision,
        @token_bucket_capacity,
        @token_bucket_rate,
        @file_single
      ]
    end

    def service_key_ok?
      # only required for ssl reporter, always return true for other reporters
      if @reporter == 'ssl' &&
        !(@service_key =~ /^[0-9a-fA-F]{64}:[-.:_?\\\/\w ]{1,255}$/ ||   # API token
          @service_key =~ /^[0-9a-zA-Z_\-]{71}:[-.:_?\\\/\w ]{1,255}$/ ) # SWOKEN

        match = @service_key.match( /([^:]+)(:{0,1})([^:]*)/ )
        masked = match ? "#{match[1][0..1]}...#{match[1][-4..-1]}#{match[2]}#{match[3]}" : ''
        AppOpticsAPM.logger.error "[appoptics_apm/oboe_options] APPOPTICS_SERVICE_KEY problem. No service name or api token in wrong format. Cannot submit data. Key: #{masked}"
        return false
      end
      true
    end

    private

    def reporter_and_host

      @reporter = ENV['APPOPTICS_REPORTER'] || 'ssl'
      # override with 'file', e.g. when running tests
      @reporter = 'file' if ENV.key?('APPOPTICS_GEM_TEST')

      @host = ''
      case @reporter
      when 'ssl', 'file'
        @host = ENV['APPOPTICS_COLLECTOR'] || ''
      when 'udp'
        @host = ENV['APPOPTICS_COLLECTOR'] ||
                "#{AppOpticsAPM::Config[:reporter_host]}:#{AppOpticsAPM::Config[:reporter_port]}"
        # TODO decide what to do
        # ____ AppOpticsAPM::Config[:reporter_host] and
        # ____ AppOpticsAPM::Config[:reporter_port] were moved here from
        # ____ oboe_metal.rb and are not documented anywhere
      when 'null'
        @host = ''
      end

    end
  end
end