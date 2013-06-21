require 'spec_helper'

describe Oboe::Inst::Resque do
  it 'Stock Resque should be loaded, defined and ready' do
    defined?(::Resque).should_not == nil 
    defined?(::Resque::Worker).should_not == nil
    defined?(::Resque::Job).should_not == nil
  end

  it 'Resque should have oboe methods defined' do
    [ :enqueue, :enqueue_to, :dequeue ].each do |m|
      ::Resque.method_defined?("#{m}_with_oboe").should == true
    end

    ::Resque::Worker.method_defined?("perform_with_oboe").should == true
    ::Resque::Job.method_defined?("fail_with_oboe").should == true
  end
end
