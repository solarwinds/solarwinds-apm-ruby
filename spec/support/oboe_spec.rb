require 'spec_helper'

describe Oboe do
  it 'should return correct version string' do
    Oboe::Version::STRING.should == "1.4.0.1"
  end
end
