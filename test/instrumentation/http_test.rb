require 'minitest_helper'


describe Oboe::Inst do
  it 'Net::HTTP should be defined and ready' do
    defined?(::Net::HTTP).wont_match nil 
  end

  it 'Net::HTTP should have oboe methods defined' do
    [ :request_with_oboe ].each do |m|
      ::Net::HTTP.method_defined?(m).must_equal true
    end
  end
end
