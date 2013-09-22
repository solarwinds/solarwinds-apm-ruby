require 'minitest_helper'

describe Oboe::Inst::Moped do
  it 'Stock Moped should be loaded, defined and ready' do
    defined?(::Moped).wont_match nil 
    defined?(::Moped::Database).wont_match nil
    defined?(::Moped::Indexes).wont_match nil
    defined?(::Moped::Query).wont_match nil
    defined?(::Moped::Collection).wont_match nil
  end

  it 'Moped should have oboe methods defined' do
    #::Moped::Database
    Oboe::Inst::Moped::DB_OPS.each do |m|
      ::Moped::Database.method_defined?("#{m}_with_oboe").must_equal true
    end
    ::Moped::Database.method_defined?(:extract_trace_details).must_equal true
    ::Moped::Database.method_defined?(:command_with_oboe).must_equal true
    ::Moped::Database.method_defined?(:drop_with_oboe).must_equal true

    #::Moped::Indexes
    Oboe::Inst::Moped::INDEX_OPS.each do |m|
      ::Moped::Indexes.method_defined?("#{m}_with_oboe").must_equal true
    end
    ::Moped::Indexes.method_defined?(:extract_trace_details).must_equal true
    ::Moped::Indexes.method_defined?(:create_with_oboe).must_equal true
    ::Moped::Indexes.method_defined?(:drop_with_oboe).must_equal true

    #::Moped::Query
    Oboe::Inst::Moped::QUERY_OPS.each do |m|
      ::Moped::Query.method_defined?("#{m}_with_oboe").must_equal true
    end
    ::Moped::Query.method_defined?(:extract_trace_details).must_equal true

    #::Moped::Collection
    Oboe::Inst::Moped::COLLECTION_OPS.each do |m|
      ::Moped::Collection.method_defined?("#{m}_with_oboe").must_equal true
    end
    ::Moped::Collection.method_defined?(:extract_trace_details).must_equal true
  end
end
