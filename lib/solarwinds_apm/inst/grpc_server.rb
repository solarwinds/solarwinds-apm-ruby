# Copyright (c) 2018 SolarWinds, LLC.
# All rights reserved.

module SolarWindsAPM
  module GRPC

    if defined? ::GRPC
      STATUSCODES = {}
      ::GRPC::Core::StatusCodes.constants.each { |code| STATUSCODES[::GRPC::Core::StatusCodes.const_get(code)] = code }
    end

    module RpcDesc

      def self.included(klass)
        ::SolarWindsAPM::Util.method_alias(klass, :handle_request_response, ::GRPC::RpcDesc)
        ::SolarWindsAPM::Util.method_alias(klass, :handle_client_streamer, ::GRPC::RpcDesc)
        ::SolarWindsAPM::Util.method_alias(klass, :handle_server_streamer, ::GRPC::RpcDesc)
        ::SolarWindsAPM::Util.method_alias(klass, :handle_bidi_streamer, ::GRPC::RpcDesc)
        ::SolarWindsAPM::Util.method_alias(klass, :run_server_method, ::GRPC::RpcDesc)
      end

      def grpc_tags(active_call, mth)
        tags = {
          'Spec' => 'grpc_server',
          'URL' => active_call.metadata['method'],
          'Controller' => mth.owner.to_s,
          'Action' => mth.name.to_s,
          'HTTP-Host' => active_call.peer
        }

        if request_response?
          tags['GRPCMethodType'] = 'UNARY'
        elsif client_streamer?
          tags['GRPCMethodType'] = 'CLIENT_STREAMING'
        elsif server_streamer?
          tags['GRPCMethodType'] = 'SERVER_STREAMING'
        else
          # is a bidi_stream
          tags['GRPCMethodType'] = 'BIDI_STREAMING'
        end

        tags
      end

      def handle_request_response_with_sw_apm(active_call, mth, inter_ctx)
        handle_call('handle_request_response_without_sw_apm', active_call, mth, inter_ctx)
      end

      def handle_client_streamer_with_sw_apm(active_call, mth, inter_ctx)
        handle_call('handle_client_streamer_without_sw_apm', active_call, mth, inter_ctx)
      end

      def handle_server_streamer_with_sw_apm(active_call, mth, inter_ctx)
        handle_call('handle_server_streamer_without_sw_apm', active_call, mth, inter_ctx)
      end

      def handle_bidi_streamer_with_sw_apm(active_call, mth, inter_ctx)
        handle_call('handle_bidi_streamer_without_sw_apm', active_call, mth, inter_ctx)
      end

      # status codes need to be determined in this lower method, because they may not get raised to the
      # next instrumented method
      def handle_call(without, active_call, mth, inter_ctx)
        begin
          send(without, active_call, mth, inter_ctx)
        rescue ::GRPC::Core::CallError, ::GRPC::BadStatus, ::GRPC::Core::OutOfTime, StandardError, NotImplementedError => e
          log_grpc_exception(active_call, e)
          raise e
        end
      end

      def run_server_method_with_sw_apm(active_call, mth, inter_ctx)
        tags = grpc_tags(active_call, mth)

        SolarWindsAPM::API.log_start('grpc-server', tags, active_call.metadata)

        begin
          SolarWindsAPM::API.send_metrics('grpc-server', tags) do
            run_server_method_without_sw_apm(active_call, mth, inter_ctx)
          end
        rescue => e
          log_grpc_exception(active_call, e)
          raise e
        ensure
          tags['GRPCStatus'] = active_call.metadata_to_send.delete('grpc_status')
          tags['GRPCStatus'] ||= active_call.status ? SolarWindsAPM::GRPC::STATUSCODES[active_call.status.code].to_s : 'OK'
          tags['Backtrace'] = SolarWindsAPM::API.backtrace if SolarWindsAPM::Config[:grpc_server][:collect_backtraces]

          SolarWindsAPM::API.log_end('grpc-server', tags)
        end
      end

      private

      def log_grpc_exception(active_call, e)
        unless e.instance_variable_get(:@exn_logged)
          SolarWindsAPM::API.log_exception('grpc-server', e)

          unless active_call.metadata_sent
            if e.class == ::GRPC::Core::OutOfTime
              active_call.merge_metadata_to_send({ 'grpc_status' => 'DEADLINE_EXCEEDED' })
            elsif e.respond_to?(:code)
              active_call.merge_metadata_to_send({ 'grpc_status' => SolarWindsAPM::GRPC::STATUSCODES[e.code].to_s })
            else
              active_call.merge_metadata_to_send({ 'grpc_status' => 'UNKNOWN' })
            end
          end
        end
      end

    end

  end
end

if defined?(GRPC) && SolarWindsAPM::Config['grpc_server'][:enabled]
  # server side is instrumented in RpcDesc
  SolarWindsAPM::Util.send_include(GRPC::RpcDesc, SolarWindsAPM::GRPC::RpcDesc)
end
