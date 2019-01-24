# Copyright (c) 2017 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require 'rack/test'
require 'rack/handler/puma'
require 'appoptics_apm/inst/rack'
require 'mocha/minitest'

describe AppOpticsAPM::SDK do

  # Transaction names are stored as a tag value on trace metrics
  # Tag values must match the regular expression /\A[-.:_\\\/\w ]{1,255}\z/.
  # Tag values are always converted to lower case.

  include Rack::Test::Methods

  def app
    @app = Rack::Builder.new {
      use Rack::CommonLogger
      use Rack::ShowExceptions
      use AppOpticsAPM::Rack

      map "/lobster" do
        run Proc.new {
          AppOpticsAPM::API.set_transaction_name("lobster")
          [200, {"Content-Type" => "text/html"}, ['Hello AppOpticsAPM!']]
        }
      end

      map "/no_name" do
        run Proc.new { [200, {"Content-Type" => "text/html"}, ['Hello AppOpticsAPM!']] }
      end

      map "/multi" do
        AppOpticsAPM::API.set_transaction_name("multi_0")
        run Proc.new {
          AppOpticsAPM::API.set_transaction_name("multi_1")
          AppOpticsAPM::API.set_transaction_name("multi")
          [200, {"Content-Type" => "text/html"}, ['Hello AppOpticsAPM!']]
        }
      end
    }
  end


  before do
    @url = "http://example.org/"
    @domain = "example.org"
    AppOpticsAPM.config_lock.synchronize {
      @tm = AppOpticsAPM::Config[:tracing_mode]
      @sample_rate = AppOpticsAPM::Config[:sample_rate]
      @prepend_domain = AppOpticsAPM::Config['transaction_name']['prepend_domain']
    }
  end

  after do
    AppOpticsAPM.config_lock.synchronize {
      AppOpticsAPM::Config[:tracing_mode] = @tm
      AppOpticsAPM::Config[:sample_rate] = @sample_rate
      AppOpticsAPM::Config['transaction_name']['prepend_domain'] = @prepend_domain
    }

    # need to do this, because we are stubbing log_end
    AppOpticsAPM.layer = nil
    AppOpticsAPM::Context.clear
  end

  it 'should set a custom transaction name from the controller' do
    name = "lobster"
    url = "#{@url}#{name}"

    # this transaction name should not be used
    AppOpticsAPM::API.set_transaction_name("another_name")

    Time.stub(:now, Time.at(0)) do
      AppOpticsAPM::Span.expects(:createHttpSpan).with(name, url, nil, 0, 200, 'GET', 0).returns(name)
      AppOpticsAPM::API.expects(:log_end).with(:rack, :Status => 200, :TransactionName => name)

      get "/#{name}"

    end
  end

  it 'should not use a different transaction name if none is set in the controller (OOTB)' do
    name = 'no_name'
    url = "#{@url}#{name}"

    # this transaction name should not be used
    AppOpticsAPM::API.set_transaction_name("another_name")

    Time.stub(:now, Time.at(0)) do
      AppOpticsAPM::Span.expects(:createHttpSpan).with(nil, url, nil, 0, 200, 'GET', 0).returns("c.a")
      AppOpticsAPM::API.expects(:log_end).with(:rack, :Status => 200, :TransactionName => "c.a")

      get "/#{name}"
    end
  end

  it 'should replace a transaction name depending on the answer by createHttpSpan' do
    name = "lobster"
    url = "#{@url}#{name}"

    Time.stub(:now, Time.at(0)) do
      AppOpticsAPM::Span.expects(:createHttpSpan).with(name, url, nil, 0, 200, 'GET', 0).returns("other")
      AppOpticsAPM::API.expects(:log_end).with(:rack, :Status => 200, :TransactionName => "other")

      get "/#{name}"
    end
  end

  it 'should use the transaction name for metrics even when not sampling' do
    AppOpticsAPM.config_lock.synchronize {
      AppOpticsAPM::Config[:sample_rate] = 0
    }
    name = "lobster"
    url = "#{@url}#{name}"
    
    Time.stub(:now, Time.at(0)) do
      AppOpticsAPM::Span.expects(:createHttpSpan).with(name, url, nil, 0, 200, 'GET', 0)
      AppOpticsAPM::API.expects(:log_event).never

      get "/#{name}"
    end
  end

  it 'should use the last transaction name from multiple calls' do
    name = 'multi'
    url = "#{@url}#{name}"

    AppOpticsAPM::API.set_transaction_name("another_name")
    Time.stub(:now, Time.at(0)) do
      AppOpticsAPM::Span.expects(:createHttpSpan).with(name, url, nil, 0, 200, 'GET', 0).returns(name)
      AppOpticsAPM::API.expects(:log_end).with(:rack, :Status => 200, :TransactionName => name)

      get "/#{name}"
    end
  end

  it 'should provide the domain name to createHttpSpan if configured' do
    AppOpticsAPM::Config['transaction_name']['prepend_domain'] = true

    name = "lobster"
    url = "#{@url}#{name}"

    Time.stub(:now, Time.at(0)) do
      AppOpticsAPM::Span.expects(:createHttpSpan).with(name, url, "example.org", 0, 200, 'GET', 0).returns(name)

      get "/#{name}"
    end
  end

  it 'should not provide the domain name to createHttpSpan if not configured' do
    AppOpticsAPM::Config['transaction_name']['prepend_domain'] = false

    name = "lobster"
    url = "#{@url}#{name}"

    Time.stub(:now, Time.at(0)) do
      AppOpticsAPM::Span.expects(:createHttpSpan).with(name, url, nil, 0, 200, 'GET', 0)

      get "/#{name}"
    end
  end

  it 'should include the port if it is not a default port' do
    AppOpticsAPM::Config['transaction_name']['prepend_domain'] = true

    name = "lobster"

    ::Rack::Request.any_instance.stubs(:port).returns(12345)
    Time.stub(:now, Time.at(0)) do
      AppOpticsAPM::Span.expects(:createHttpSpan).with(name, "http://example.org:12345/lobster", "example.org:12345", 0, 200, 'GET', 0)

      get "/#{name}"
    end

  end

  # Let's test createHttpSpan a bit too
  it 'should prepend the domain to the url if no transaction name given' do
    assert_equal "example.org:80/lobster", AppOpticsAPM::Span.createHttpSpan(nil, "/lobster", "example.org:80", 0, 200, 'GET', 0)
    assert_equal "example.org:80/lobster", AppOpticsAPM::Span.createHttpSpan(nil, "example.org/lobster", "example.org:80", 0, 200, 'GET', 0)
    assert_equal "example.org:80/lobster", AppOpticsAPM::Span.createHttpSpan(nil, "example.org:80/lobster", "example.org:80", 0, 200, 'GET', 0)
    assert_equal "example.org:80/", AppOpticsAPM::Span.createHttpSpan(nil, nil, "example.org:80", 0, 200, 'GET', 0)
    assert_equal "unknown", AppOpticsAPM::Span.createHttpSpan(nil, nil, nil, 0, 200, 'GET', 0)
  end
end
