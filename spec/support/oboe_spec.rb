require 'spec_helper'

describe Oboe do
  it 'should return correct version string' do
    Oboe::Version::STRING.should =~ /2.0.0/
  end
end
