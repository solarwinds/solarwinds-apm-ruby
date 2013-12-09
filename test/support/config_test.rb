require 'minitest_helper'

describe Oboe::Config do
  after do
    # Set back to always trace mode
    Oboe::Config[:tracing_mode] = "always"
    Oboe::Config[:sample_rate] = 1000000
  end

  it 'should have the correct default values' do
    # Reset Oboe::Config to defaults
    Oboe::Config.initialize

    Oboe::Config[:verbose].must_equal false
    Oboe::Config[:tracing_mode].must_equal "through"
    Oboe::Config[:reporter_host].must_equal "127.0.0.1"
  end

  it 'should have the correct instrumentation defaults' do
    # Reset Oboe::Config to defaults
    Oboe::Config.initialize

    instrumentation = [ :cassandra, :dalli, :nethttp, :memcached, :memcache, :mongo,
                        :moped, :rack, :resque, :action_controller, :action_view,
                        :active_record ]

    # Verify the number of individual instrumentations
    instrumentation.count.must_equal 12

    instrumentation.each do |k|
      Oboe::Config[k][:enabled].must_equal true
      Oboe::Config[k][:log_args].must_equal true
    end

    Oboe::Config[:resque][:link_workers].must_equal false
    Oboe::Config[:blacklist].is_a?(Array).must_equal true
  end

end
