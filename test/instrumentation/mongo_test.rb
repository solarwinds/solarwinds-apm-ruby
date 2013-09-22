require 'minitest_helper'

describe Oboe::Inst::Mongo do
  it 'Stock Mongo should be loaded, defined and ready' do
    defined?(::Mongo).wont_match nil 
    defined?(::Mongo::DB).wont_match nil
    defined?(::Mongo::Cursor).wont_match nil
    defined?(::Mongo::Collection).wont_match nil
  end

  it 'Mongo should have oboe methods defined' do
    Oboe::Inst::Mongo::DB_OPS.each do |m|
      ::Mongo::DB.method_defined?("#{m}_with_oboe").must_equal true
    end
    Oboe::Inst::Mongo::CURSOR_OPS.each do |m|
      ::Mongo::Cursor.method_defined?("#{m}_with_oboe").must_equal true
    end
    Oboe::Inst::Mongo::COLL_WRITE_OPS.each do |m|
      ::Mongo::Collection.method_defined?("#{m}_with_oboe").must_equal true
    end
    Oboe::Inst::Mongo::COLL_QUERY_OPS.each do |m|
      ::Mongo::Collection.method_defined?("#{m}_with_oboe").must_equal true
    end
    Oboe::Inst::Mongo::COLL_INDEX_OPS.each do |m|
      ::Mongo::Collection.method_defined?("#{m}_with_oboe").must_equal true
    end
    ::Mongo::Collection.method_defined?(:oboe_collect).must_equal true
  end
end
