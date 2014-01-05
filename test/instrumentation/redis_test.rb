require 'minitest_helper'

describe Oboe::Inst::Redis do
  before do
    clear_all_traces 

    # These are standard entry/exit KVs that are passed up with all moped operations
    @entry_kvs = {
      'Layer' => 'redis',
      'Label' => 'entry' }

    @exit_kvs = { 'Layer' => 'redis', 'Label' => 'exit' }
  end

  it 'Stock Redis should be loaded, defined and ready' do
    defined?(::Redis).wont_match nil 
  end

  it "should have tests implemented" do
    skip "tests not implemented yet =|:-(>"
  end
end

