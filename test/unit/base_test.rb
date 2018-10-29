require 'minitest_helper'
require 'mocha/minitest'

describe 'AppOpticsAPMBase' do

  describe 'tracing_layer_op?' do
    after do
      AppOpticsAPM.layer_op = nil
    end

    it 'should return false for nil op' do
      refute AppOpticsAPM.tracing_layer_op?(nil)
    end

    it 'should return false for op that cannot be symbolized' do
      refute AppOpticsAPM.tracing_layer_op?([1,2])
    end

    it 'should return false when layer_op is nil' do
      AppOpticsAPM.layer_op = nil
      refute AppOpticsAPM.tracing_layer_op?('whoot?')
    end

     it 'should return false when layer_op is empty' do
       AppOpticsAPM.layer_op = []
       refute AppOpticsAPM.tracing_layer_op?('well?')
    end

    # this should be prevented otherwise, but how?
    # also layer_op should only contain symbols!
    it 'should log an error and return false when layer_op is not an array' do
      AppOpticsAPM.logger.expects(:error)
      AppOpticsAPM.layer_op = 'I should no be a string'
      refute AppOpticsAPM.tracing_layer_op?(nil)
    end

    it 'should return true when op is last in layer_op' do
       AppOpticsAPM.layer_op = [:one]
       assert AppOpticsAPM.tracing_layer_op?('one')
       AppOpticsAPM.layer_op = [:one, :two]
       assert AppOpticsAPM.tracing_layer_op?('two')
    end

    it 'should return false when op is not last in layer_op' do
      AppOpticsAPM.layer_op = [:one, :two]
      refute AppOpticsAPM.tracing_layer_op?('one')
    end

    it 'should return false when op is not in layer_op' do
      AppOpticsAPM.layer_op = [:one, :two]
      refute AppOpticsAPM.tracing_layer_op?('three')
    end
  end

end