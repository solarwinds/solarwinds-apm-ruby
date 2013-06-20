require 'spec_helper'

describe Oboe::Config do
  
  it 'should have the correct default values' do
    Oboe::Config[:verbose].should == false
    Oboe::Config[:sample_rate].should == 1000000
    Oboe::Config[:tracing_mode].should == "through"
    Oboe::Config[:reporter_host].should == "127.0.0.1"
  end

  it 'should have the correct instrumentation defaults' do

    instrumentation = [ :cassandra, :dalli, :nethttp, :memcached, :memcache, :mongo,
                        :moped, :rack, :resque, :action_controller, :action_view,
                        :active_record ]

    # Verify the number of individual instrumentations
    instrumentation.count.should == 12

    instrumentation.each do |k|
      Oboe::Config[k][:enabled].should   == true
      Oboe::Config[k][:log_args].should  == true
    end
  end

end
