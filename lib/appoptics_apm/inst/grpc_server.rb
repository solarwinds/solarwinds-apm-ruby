# Copyright (c) 2018 SolarWinds, LLC.
# All rights reserved.

module AppOpticsAPM
  module GRPC

    if defined? ::GRPC
      STATUSCODES = {}
      ::GRPC::Core::StatusCodes.constants.each { |code| STATUSCODES[::GRPC::Core::StatusCodes.const_get(code)] = code }
    end

    module RpcDesc

      def self.included(klass)
        ::AppOpticsAPM::Util.method_alias(klass, :handle_request_response, ::GRPC::RpcDesc)
        ::AppOpticsAPM::Util.method_alias(klass, :handle_client_streamer, ::GRPC::RpcDesc)
        ::AppOpticsAPM::Util.method_alias(klass, :handle_server_streamer, ::GRPC::RpcDesc)
        ::AppOpticsAPM::Util.method_alias(klass, :handle_bidi_streamer, ::GRPC::RpcDesc)
        ::AppOpticsAPM::Util.method_alias(klass, :run_server_method, ::GRPC::RpcDesc)
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
        else  # is a bidi_stream
          tags['GRPCMethodType'] = 'BIDI_STREAMING'
        end

        tags
      end

      def handle_request_response_with_appoptics(active_call, mth, inter_ctx)
        handle_call('handle_request_response_without_appoptics', active_call, mth, inter_ctx)
      end

      def handle_client_streamer_with_appoptics(active_call, mth, inter_ctx)
        handle_call('handle_client_streamer_without_appoptics', active_call, mth, inter_ctx)
      end

      def handle_server_streamer_with_appoptics(active_call, mth, inter_ctx)
        handle_call('handle_server_streamer_without_appoptics', active_call, mth, inter_ctx)
      end

      def handle_bidi_streamer_with_appoptics(active_call, mth, inter_ctx)
        handle_call('handle_bidi_streamer_without_appoptics', active_call, mth, inter_ctx)
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

      def run_server_method_with_appoptics(active_call, mth, inter_ctx)
        tags = grpc_tags(active_call, mth)
        AppOpticsAPM::API.log_start('grpc-server', active_call.metadata['x-trace'], tags)

        exit_event = AppOpticsAPM::Event.startTrace(AppOpticsAPM::Context.get)
        active_call.merge_metadata_to_send({ 'x-trace' => exit_event.metadataString })
        begin
          AppOpticsAPM::API.send_metrics('grpc-server', tags) do
            run_server_method_without_appoptics(active_call, mth, inter_ctx)
          end
        rescue => e
          log_grpc_exception(active_call, e)
          raise e
        ensure
          tags['GRPCStatus'] = active_call.metadata_to_send.delete('grpc_status')
          tags['GRPCStatus'] ||= active_call.status ? AppOpticsAPM::GRPC::STATUSCODES[active_call.status.code].to_s : 'OK'
          tags['Backtrace'] = AppOpticsAPM::API.backtrace if AppOpticsAPM::Config[:grpc_server][:collect_backtraces]

          exit_event.addEdge(AppOpticsAPM::Context.get)
          AppOpticsAPM::API.log_end('grpc-server', tags, exit_event)
        end
      end

      private

      def log_grpc_exception(active_call, e)
        unless e.instance_variable_get(:@exn_logged)
          AppOpticsAPM::API.log_exception('grpc-server', e)

          unless active_call.metadata_sent
            if e.class == ::GRPC::Core::OutOfTime
              active_call.merge_metadata_to_send({ 'grpc_status' => 'DEADLINE_EXCEEDED' })
            elsif e.respond_to?(:code)
              active_call.merge_metadata_to_send({ 'grpc_status' =>  AppOpticsAPM::GRPC::STATUSCODES[e.code].to_s })
            else
              active_call.merge_metadata_to_send({ 'grpc_status' =>  'UNKNOWN' })
            end
          end
        end
      end

    end

  end
end

if defined?(GRPC) && AppOpticsAPM::Config['grpc_server'][:enabled]
  # server side is instrumented in RpcDesc
  AppOpticsAPM::Util.send_include(GRPC::RpcDesc, AppOpticsAPM::GRPC::RpcDesc)
end
