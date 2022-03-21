# Copyright (c) 2018 SolarWinds, LLC.
# All rights reserved.

module SolarWindsAPM
  module GRPC

    module ActiveCall
      include SolarWindsAPM::SDK::TraceContextHeaders

      if defined? ::GRPC
        StatusCodes = {}
        ::GRPC::Core::StatusCodes.constants.each { |code| StatusCodes[::GRPC::Core::StatusCodes.const_get(code)] = code }
      end

      def self.included(klass)
        SolarWindsAPM::Util.method_alias(klass, :request_response, ::GRPC::ActiveCall)
        SolarWindsAPM::Util.method_alias(klass, :client_streamer, ::GRPC::ActiveCall)
        SolarWindsAPM::Util.method_alias(klass, :server_streamer, ::GRPC::ActiveCall)
        SolarWindsAPM::Util.method_alias(klass, :bidi_streamer, ::GRPC::ActiveCall)
      end

      def grpc_tags(method_type, method)
        tags = { 'Spec' => 'rsc',
                 'RemoteURL' => "grpc://#{peer}#{method}",
                 'GRPCMethodType' => method_type,
                 'IsService' => 'True'
        }
        tags
      end

      def request_response_with_appoptics(req, metadata: {})
        unary_response(req, type: 'UNARY', metadata: metadata, without: :request_response_without_appoptics)
      end

      def client_streamer_with_appoptics(req, metadata: {})
        unary_response(req, type: 'CLIENT_STREAMING', metadata: metadata, without: :client_streamer_without_appoptics)
      end

      def server_streamer_with_appoptics(req, metadata: {}, &blk)
        @tags = grpc_tags('SERVER_STREAMING', metadata['method'] || metadata_to_send['method'])
        SolarWindsAPM::API.log_entry('grpc-client', @tags)
        add_tracecontext_headers(metadata)

        patch_receive_and_check_status # need to patch this so that log_exit can be called after the enum is consumed

        response = server_streamer_without_appoptics(req, metadata: metadata)
        block_given? ? response.each { |r| yield r } : response
      rescue => e
        # this check is needed because the exception may have been logged in patch_receive_and_check_status
        unless e.instance_variable_get(:@exn_logged)
          SolarWindsAPM::API.log_exception('grpc-client', e)
          SolarWindsAPM::API.log_exit('grpc-client', exit_tags(@tags))
        end
        raise e
      end

      def bidi_streamer_with_appoptics(req, metadata: {}, &blk)
        @tags = grpc_tags('BIDI_STREAMING', metadata['method'] || metadata_to_send['method'])
        SolarWindsAPM::API.log_entry('grpc-client', @tags)
        add_tracecontext_headers(metadata)

        patch_set_input_stream_done

        response = bidi_streamer_without_appoptics(req, metadata: metadata)
        block_given? ? response.each { |r| yield r } : response
      rescue => e
        unless e.instance_variable_get(:@exn_logged)
          SolarWindsAPM::API.log_exception('grpc-client', e)
          SolarWindsAPM::API.log_exit('grpc-client', exit_tags(@tags))
        end
        raise e
      end

      private

      def unary_response(req, type:, metadata:, without:)
        tags = grpc_tags(type, metadata['method'] || metadata_to_send['method'])
        SolarWindsAPM::SDK.trace('grpc-client', kvs: tags) do
          add_tracecontext_headers(metadata)
          begin
            send(without, req, metadata: metadata)
          ensure
            exit_tags(tags)
          end
        end
      end

      def patch_receive_and_check_status
        def self.receive_and_check_status # need to patch this so that log_exit can be called after the enum is consumed
          super
        rescue => e
          SolarWindsAPM::API.log_exception('grpc-client', e)
          raise e
        ensure
          SolarWindsAPM::API.log_exit('grpc-client', exit_tags(@tags))
        end
      end

      def patch_set_input_stream_done
        # need to patch this instance method so that log_exit can be called after the enum is consumed
        def self.set_input_stream_done
          return if status.nil?
          if status.code > 0
            SolarWindsAPM::API.log_exception('grpc-client', $!)
          end
          SolarWindsAPM::API.log_exit('grpc-client', exit_tags(@tags))
          super
        end
      end

      def exit_tags(tags)
        # we need to translate the status.code, it is not the status.details we want, they are not matching 1:1
        tags['GRPCStatus'] ||= @call.status ? StatusCodes[@call.status.code].to_s : 'UNKNOWN'
        tags['Backtrace'] = SolarWindsAPM::API.backtrace if SolarWindsAPM::Config[:grpc_client][:collect_backtraces]
        tags
      end
    end

  end
end

if defined?(GRPC) && SolarWindsAPM::Config[:grpc_client][:enabled]
  SolarWindsAPM.logger.info '[appoptics_apm/loading] Instrumenting GRPC' if SolarWindsAPM::Config[:verbose]

  # Client side is instrumented in ActiveCall and ClientStub
  SolarWindsAPM::Util.send_include(GRPC::ActiveCall, SolarWindsAPM::GRPC::ActiveCall)

  GRPC_ClientStub_ops = [:request_response, :client_streamer, :server_streamer, :bidi_streamer]
  module GRPC
    class ClientStub
      GRPC_ClientStub_ops.reject { |m| !method_defined?(m) }.each do |m|
        define_method("#{m}_with_appoptics") do |method, req, marshal, unmarshal, deadline: nil,
          return_op: false, parent: nil,
          credentials: nil, metadata: {}, &blk|

          metadata['method'] = method
          return send("#{m}_without_appoptics", method, req, marshal, unmarshal, deadline: deadline,
                      return_op: return_op, parent: parent,
                      credentials: credentials, metadata: metadata, &blk)
        end

        SolarWindsAPM::Util.method_alias(GRPC::ClientStub, m)
      end

    end
  end
end
