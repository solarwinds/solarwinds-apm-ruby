require 'spec_helper'

describe Oboe::Inst::Mongo do
  it 'Stock Mongo should be loaded, defined and ready' do
    defined?(::Mongo).should_not == nil 
    defined?(::Mongo::DB).should_not == nil
    defined?(::Mongo::Cursor).should_not == nil
    defined?(::Mongo::Collection).should_not == nil
  end

  it 'Mongo should have oboe methods defined' do
    Oboe::Inst::Mongo::DB_OPS.each do |m|
      ::Mongo::DB.method_defined?("#{m}_with_oboe").should == true
    end
    Oboe::Inst::Mongo::CURSOR_OPS.each do |m|
      ::Mongo::Cursor.method_defined?("#{m}_with_oboe").should == true
    end
    Oboe::Inst::Mongo::COLL_WRITE_OPS.each do |m|
      ::Mongo::Collection.method_defined?("#{m}_with_oboe").should == true
    end
    Oboe::Inst::Mongo::COLL_QUERY_OPS.each do |m|
      ::Mongo::Collection.method_defined?("#{m}_with_oboe").should == true
    end
    Oboe::Inst::Mongo::COLL_INDEX_OPS.each do |m|
      ::Mongo::Collection.method_defined?("#{m}_with_oboe").should == true
    end
    ::Mongo::Collection.method_defined?(:oboe_collect).should == true
  end
end
