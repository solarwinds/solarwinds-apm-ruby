module  AppOpticsAPM
  module API
    module Metrics

      ##
      # Internal: method to send duration for a transaction
      # it checks if it can send metrics with the current transaction name
      # or a default transaction name and sets the transaction name accordingly
      #
      # === Arguments
      #
      # * +span+ the name of the current span (used to construct a transaction name if none is defined)
      # * +kvs+ A hash containing key/value pairs, only the value of :TransactionName will be relevant
      #
      # Returns the result of the block.
      #

      def send_metrics(span, kvs = {})
        # This is a new span, we do not know the transaction name yet
        AppOpticsAPM.transaction_name = nil

        # if a transaction name is provided it will take precedence over transaction names defined
        # later or in lower spans
        transaction_name = set_transaction_name(kvs[:TransactionName])
        start = Time.now

        yield
      ensure
        duration =(1000 * 1000 * (Time.now - start)).round(0)
        transaction_name ||= AppOpticsAPM.transaction_name || "custom-#{span}"
        set_transaction_name(AppOpticsAPM::Span.createSpan(transaction_name, nil, duration))
      end
    end
  end
end