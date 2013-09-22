require 'minitest_helper'

describe Oboe::Inst::Cassandra do
  it 'Stock Cassandra should be loaded, defined and ready' do
    defined?(::Cassandra).wont_match nil 
  end

  it 'Cassandra should have oboe methods defined' do
    [ :insert, :remove, :count_columns, :get_columns, :multi_get_columns, :get,
      :multi_get, :get_range_single, :get_range_batch, :get_indexed_slices,
      :create_index, :drop_index, :add_column_family, :drop_column_family,
      :add_keyspace, :drop_keyspace ].each do |m|
      ::Cassandra.method_defined?("#{m}_with_oboe").must_equal true
    end
    # Special 'exists?' case
    ::Cassandra.method_defined?("exists_with_oboe?").must_equal true
  end
end
