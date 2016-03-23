# Copyright (c) 2013 AppNeta, Inc.
# All rights reserved.

require 'json'

module TraceView
  module Mongo2
    module Collection
      def self.included(klass)
        ::TraceView::Util.method_alias(klass, :create)
        ::TraceView::Util.method_alias(klass, :drop)
      end

      ##
      # collect_kvs
      #
      # Used to collect up information to report and build a hash
      # with the Keys/Values to report.
      #
      def collect_kvs
        kvs = { :Flavor => :mongodb, :Database => @database.name }

        kvs[:RemoteHost] = @database.client.cluster.addresses.first.to_s
        kvs[:Backtrace] = TraceView::API.backtrace if TraceView::Config[:mongo][:collect_backtraces]
      rescue => e
        TraceView.logger.debug "[traceview/debug] #{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}" if TraceView::Config[:verbose]
      ensure
        return kvs
      end

      def create_with_traceview
        return create_without_traceview unless TraceView.tracing?

        kvs = collect_kvs
        kvs[:QueryOp] = :create_collection
        kvs[:New_Collection_Name] = @name

        TraceView::API.log_entry(:mongo, kvs)

        create_without_traceview
      rescue => e
        TraceView::API.log_exception(:mongo, e)
        raise e
      ensure
        TraceView::API.log_exit(:mongo)
      end

      def drop_with_traceview
        return drop_without_traceview unless TraceView.tracing?

        kvs = collect_kvs
        kvs[:QueryOp] = :drop_collection
        kvs[:Collection] = @name

        TraceView::API.log_entry(:mongo, kvs)

        drop_without_traceview
      rescue => e
        TraceView::API.log_exception(:mongo, e)
        raise e
      ensure
        TraceView::API.log_exit(:mongo)
      end
    end
  end
end

if RUBY_VERSION >= '1.9' && TraceView::Config[:mongo][:enabled]
  if defined?(::Mongo) && (Gem.loaded_specs['mongo'].version.to_s >= '2.0.0')
    ::TraceView.logger.info '[traceview/loading] Instrumenting mongo' if TraceView::Config[:verbose]
    ::TraceView::Util.send_include(::Mongo::Collection, ::TraceView::Mongo2::Collection)
  end
end
