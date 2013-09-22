require 'minitest_helper'

describe Oboe::Inst::Resque do
  it 'Stock Resque should be loaded, defined and ready' do
    defined?(::Resque).wont_match nil 
    defined?(::Resque::Worker).wont_match nil
    defined?(::Resque::Job).wont_match nil
  end

  it 'Resque should have oboe methods defined' do
    [ :enqueue, :enqueue_to, :dequeue ].each do |m|
      ::Resque.method_defined?("#{m}_with_oboe").must_equal true
    end

    ::Resque::Worker.method_defined?("perform_with_oboe").must_equal true
    ::Resque::Job.method_defined?("fail_with_oboe").must_equal true
  end
end
