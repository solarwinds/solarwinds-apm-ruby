#--
# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.
#++

module AppOpticsAPM
  module SDK

    module CustomMetrics

      # Send counts
      #
      # Use this method to report the number of times an action occurs. The metric counts reported are summed and flushed every 60 seconds.
      #
      # === Arguments:
      #
      # * +name+          (String) Name to be used for the metric. Must be 255 or fewer characters and consist only of A-Za-z0-9.:-*
      # * +count+         (Integer, optional, default = 1): Count of actions being reported
      # * +with_hostname+ (Boolean, optional, default = false): Indicates if the host name should be included as a tag for the metric
      # * +tags_kvs+      (Hash, optional): List of key/value pairs to describe the metric. The key must be <= 64 characters, the value must be <= 255 characters, allowed characters: A-Za-z0-9.:-_
      #
      # === Example:
      #
      #   class WorkTracker
      #     def counting(name, tags = {})
      #       yield # yield to where work is done
      #       AppOpticsAPM::SDK.increment_metric(name, 1, false, tags)
      #     end
      #   end
      #
      # === Returns:
      # * 0 on success, error code on failure
      #
      def increment_metric(name, count = 1, with_hostname = false, tags_kvs = {})
        return true unless AppOpticsAPM.loaded
        with_hostname = with_hostname ? 1 : 0
        tags, tags_count = make_tags(tags_kvs)
        AppOpticsAPM::CustomMetrics.increment(name.to_s, count, with_hostname, nil, tags, tags_count) == 1
      end

      # Send values with counts
      #
      # Use this method to report a value for each or multiple counts. The metric values reported are aggregated and flushed every 60 seconds. The dashboard displays the average value per count.
      #
      # === Arguments:
      #
      # * +name+          (String) Name to be used for the metric. Must be 255 or fewer characters and consist only of A-Za-z0-9.:-*
      # * +value+         (Numeric) Value to be added to the current sum
      # * +count+         (Integer, optional, default = 1): Count of actions being reported
      # * +with_hostname+ (Boolean, optional, default = false): Indicates if the host name should be included as a tag for the metric
      # * +tags_kvs+      (Hash, optional): List of key/value pairs to describe the metric. The key must be <= 64 characters, the value must be <= 255 characters, allowed characters: A-Za-z0-9.:-_
      #
      # === Example:
      #
      #   class WorkTracker
      #     def timing(name, tags = {})
      #       start = Time.now
      #       yield # yield to where work is done
      #       duration = Time.now - start
      #       AppOpticsAPM::SDK.summary_metric(name, duration, 1, false, tags)
      #     end
      #   end
      #
      # === Returns:
      # * 0 on success, error code on failure
      #
      def summary_metric(name, value, count = 1, with_hostname = false, tags_kvs = {})
        return true unless AppOpticsAPM.loaded
        with_hostname = with_hostname ? 1 : 0
        tags, tags_count = make_tags(tags_kvs)
        AppOpticsAPM::CustomMetrics.summary(name.to_s, value, count, with_hostname, nil, tags, tags_count) == 1
      end

      private

      def make_tags(tags_kvs)
        unless tags_kvs.is_a?(Hash)
          AppOpticsAPM.logger.warn("[appoptics_apm/metrics] CustomMetrics received tags_kvs that are not a Hash (found #{tags_kvs.class}), setting tags_kvs = {}")
          tags_kvs = {}
        end
        count = tags_kvs.size
        tags = AppOpticsAPM::MetricTags.new(count)

        tags_kvs.each_with_index do |(k, v), i|
          tags.add(i, k.to_s, v.to_s)
        end

        [tags, count]
      end
    end

    extend CustomMetrics
  end
end
