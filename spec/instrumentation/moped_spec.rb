require 'spec_helper'

describe Oboe::Inst::Moped do
  it 'Stock Moped should be loaded, defined and ready' do
    defined?(::Moped).should_not == nil 
    defined?(::Moped::Database).should_not == nil
    defined?(::Moped::Indexes).should_not == nil
    defined?(::Moped::Query).should_not == nil
    defined?(::Moped::Collection).should_not == nil
  end

  it 'Moped should have oboe methods defined' do
    #::Moped::Database
    Oboe::Inst::Moped::DB_OPS.each do |m|
      ::Moped::Database.method_defined?("#{m}_with_oboe").should == true
    end
    ::Moped::Database.method_defined?(:extract_trace_details).should == true
    ::Moped::Database.method_defined?(:command_with_oboe).should == true
    ::Moped::Database.method_defined?(:drop_with_oboe).should == true

    #::Moped::Indexes
    Oboe::Inst::Moped::INDEX_OPS.each do |m|
      ::Moped::Indexes.method_defined?("#{m}_with_oboe").should == true
    end
    ::Moped::Indexes.method_defined?(:extract_trace_details).should == true
    ::Moped::Indexes.method_defined?(:create_with_oboe).should == true
    ::Moped::Indexes.method_defined?(:drop_with_oboe).should == true

    #::Moped::Query
    Oboe::Inst::Moped::QUERY_OPS.each do |m|
      ::Moped::Query.method_defined?("#{m}_with_oboe").should == true
    end
    ::Moped::Query.method_defined?(:extract_trace_details).should == true

    #::Moped::Collection
    Oboe::Inst::Moped::COLLECTION_OPS.each do |m|
      ::Moped::Collection.method_defined?("#{m}_with_oboe").should == true
    end
    ::Moped::Collection.method_defined?(:extract_trace_details).should == true
  end
end
