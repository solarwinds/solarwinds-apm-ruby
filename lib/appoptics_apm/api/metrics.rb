module  AppOpticsAPM
  module API
    module Metrics

      ##
      # Internal: method to send duration for a transaction
      # it checks if it can send metrics with the current transaction name
      # or a default transaction name and sets the transaction name accordingly
      #
      # === Arguments:
      #
      # * +span+ the name of the current span (used to construct a transaction name if none is defined)
      # * +kvs+ A hash containing key/value pairs, only the value of :TransactionName will be relevant
      #
      # === Returns:
      # The result of the block.
      #
      # === Assigns:
      # The transaction_name to kvs[:TransactionName]

      def send_metrics(span, kvs)
        start = Time.now
        yield
      ensure
        duration =(1000 * 1000 * (Time.now - start)).round(0)
        transaction_name = determine_transaction_name(span)
        kvs[:TransactionName] = AppOpticsAPM::Span.createSpan(transaction_name, nil, duration)
        AppOpticsAPM.transaction_name = nil
      end

      private

      ##
      # Determine the transaction name to be set on the trace
      #
      # === Argument:
      # * +opts+ (hash) the value of :TransactionName will be set as custom transaction name
      #
      # === Returns:
      # (string) the current transaction name
      #
      def determine_transaction_name(span)
        AppOpticsAPM.transaction_name || AppOpticsAPM::SDK.set_transaction_name("custom-#{span}")
      end

    end
  end
end