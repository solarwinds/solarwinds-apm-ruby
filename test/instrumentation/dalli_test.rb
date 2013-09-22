require 'minitest_helper'

describe Oboe::Inst::Dalli do
  it 'Stock Dalli should be loaded, defined and ready' do
    defined?(::Dalli).wont_match nil 
    defined?(::Dalli::Client).wont_match nil
  end

  it 'Dalli should have oboe methods defined' do
    [ :perform_with_oboe, :get_multi_with_oboe ].each do |m|
      ::Dalli::Client.method_defined?(m).must_equal true
    end
  end
end
