require 'minitest_helper'

if (RUBY_VERSION =~ /^1./) == 0
  describe Oboe::Inst::Memcached do
    require 'memcached'
    require 'memcached/rails'

    it 'Stock Memcached should be loaded, defined and ready' do
      defined?(::Memcached).wont_match nil 
      defined?(::Memcached::Rails).wont_match nil 
    end

    it 'Memcached should have oboe methods defined' do
      Oboe::API::Memcache::MEMCACHE_OPS.each do |m|
        if ::Memcached.method_defined?(m)
          ::Memcached.method_defined?("#{m}_with_oboe").must_equal true 
        end
        ::Memcached::Rails.method_defined?(:get_multi_with_oboe).must_equal true 
      end
    end
  end
end
