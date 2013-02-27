require 'spec_helper'

Oboe::Inst.load_instrumentation

describe Oboe::Inst::Dalli do
  it 'Stock Dalli should be loaded, defined and ready' do
    defined?(::Dalli).should_not == nil 
    defined?(::Dalli::Client).should_not == nil
  end

  it 'Dalli should have oboe methods defined' do
    [ :perform_with_oboe, :get_multi_with_oboe ].each do |m|
      ::Dalli::Client.method_defined?(m).should == true
    end
  end
end
