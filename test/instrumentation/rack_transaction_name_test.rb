# Copyright (c) 2017 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require 'rack/test'
require 'rack/handler/puma'
require 'solarwinds_apm/inst/rack'
require 'mocha/minitest'

describe SolarWindsAPM::SDK do

  # Transaction names are stored as a tag value on trace metrics
  # Tag values must match the regular expression /\A[-.:_\\\/\w ]{1,255}\z/.
  # Tag values are always converted to lower case.

  include Rack::Test::Methods

  def app
    @app = Rack::Builder.new {
      use Rack::CommonLogger
      use Rack::ShowExceptions
      use SolarWindsAPM::Rack

      map "/lobster" do
        run Proc.new {
          SolarWindsAPM::API.set_transaction_name("lobster")
          [200, {"Content-Type" => "text/html"}, ['Hello SolarWindsAPM!']]
        }
      end

      map "/no_name" do
        run Proc.new { [200, {"Content-Type" => "text/html"}, ['Hello SolarWindsAPM!']] }
      end

      map "/multi" do
        SolarWindsAPM::API.set_transaction_name("multi_0")
        run Proc.new {
          SolarWindsAPM::API.set_transaction_name("multi_1")
          SolarWindsAPM::API.set_transaction_name("multi")
          [200, {"Content-Type" => "text/html"}, ['Hello SolarWindsAPM!']]
        }
      end
    }
  end


  before do
    @url = "http://example.org/"
    @domain = "example.org"
    SolarWindsAPM.config_lock.synchronize {
      @tm = SolarWindsAPM::Config[:tracing_mode]
      @sample_rate = SolarWindsAPM::Config[:sample_rate]
      @prepend_domain = SolarWindsAPM::Config['transaction_name']['prepend_domain']
    }
  end

  after do
    SolarWindsAPM.config_lock.synchronize {
      SolarWindsAPM::Config[:tracing_mode] = @tm
      SolarWindsAPM::Config[:sample_rate] = @sample_rate
      SolarWindsAPM::Config['transaction_name']['prepend_domain'] = @prepend_domain
    }
  end

  it 'should set a custom transaction name from the controller' do
    name = "lobster"
    url = "#{@url}#{name}"

    # this transaction name should not be used
    SolarWindsAPM::API.set_transaction_name("another_name")

    Time.stub(:now, Time.at(0)) do
      SolarWindsAPM::Span.expects(:createHttpSpan).with(name, url, nil, 0, 200, 'GET', 0).returns(name)
      SolarWindsAPM::API.expects(:log_exit).with(:rack, :Status => 200, :TransactionName => name, :ProfileSpans => -1)

      get "/#{name}"

    end
  end

  it 'should not use a different transaction name if none is set in the controller (OOTB)' do
    name = 'no_name'
    url = "#{@url}#{name}"

    # this transaction name should not be used
    SolarWindsAPM::API.set_transaction_name("another_name")

    Time.stub(:now, Time.at(0)) do
      SolarWindsAPM::Span.expects(:createHttpSpan).with(nil, url, nil, 0, 200, 'GET', 0).returns("c.a")
      SolarWindsAPM::API.expects(:log_exit).with(:rack, :Status => 200, :TransactionName => "c.a", :ProfileSpans => -1)

      get "/#{name}"
    end
  end

  it 'should replace a transaction name depending on the answer by createHttpSpan' do
    name = "lobster"
    url = "#{@url}#{name}"

    Time.stub(:now, Time.at(0)) do
      SolarWindsAPM::Span.expects(:createHttpSpan).with(name, url, nil, 0, 200, 'GET', 0).returns("other")
      SolarWindsAPM::API.expects(:log_exit).with(:rack, :Status => 200, :TransactionName => "other", :ProfileSpans => -1)

      get "/#{name}"
    end
  end

  it 'should use the transaction name for metrics even when not sampling' do
    SolarWindsAPM.config_lock.synchronize {
      SolarWindsAPM::Config[:sample_rate] = 0
    }
    name = "lobster"
    url = "#{@url}#{name}"

    Time.stub(:now, Time.at(0)) do
      SolarWindsAPM::Span.expects(:createHttpSpan).with(name, url, nil, 0, 200, 'GET', 0)
      SolarWindsAPM::API.expects(:log_event).never

      get "/#{name}"
    end
  end

  it 'should use the last transaction name from multiple calls' do
    name = 'multi'
    url = "#{@url}#{name}"

    SolarWindsAPM::API.set_transaction_name("another_name")
    Time.stub(:now, Time.at(0)) do
      SolarWindsAPM::Span.expects(:createHttpSpan).with(name, url, nil, 0, 200, 'GET', 0).returns(name)
      SolarWindsAPM::API.expects(:log_exit).with(:rack, :Status => 200, :TransactionName => name, :ProfileSpans => -1)

      get "/#{name}"
    end
  end

  it 'should provide the domain name to createHttpSpan if configured' do
    SolarWindsAPM::Config['transaction_name']['prepend_domain'] = true

    name = "lobster"
    url = "#{@url}#{name}"

    Time.stub(:now, Time.at(0)) do
      SolarWindsAPM::Span.expects(:createHttpSpan).with(name, url, "example.org", 0, 200, 'GET', 0).returns(name)

      get "/#{name}"
    end
  end

  it 'should not provide the domain name to createHttpSpan if not configured' do
    SolarWindsAPM::Config['transaction_name']['prepend_domain'] = false

    name = "lobster"
    url = "#{@url}#{name}"

    Time.stub(:now, Time.at(0)) do
      SolarWindsAPM::Span.expects(:createHttpSpan).with(name, url, nil, 0, 200, 'GET', 0)

      get "/#{name}"
    end
  end

  it 'should include the port if it is not a default port' do
    SolarWindsAPM::Config['transaction_name']['prepend_domain'] = true

    name = "lobster"

    Time.stub(:now, Time.at(0)) do
      SolarWindsAPM::Span.expects(:createHttpSpan).with(name, "http://example.org:12345/lobster", "example.org:12345", 0, 200, 'GET', 0)

      get "http://#{@domain}:12345/#{name}"
    end

  end

  # Let's test createHttpSpan a bit too
  it 'should prepend the domain to the url if no transaction name given' do
    assert_equal "example.org:80/lobster", SolarWindsAPM::Span.createHttpSpan(nil, "/lobster", "example.org:80", 0, 200, 'GET', 0)
    assert_equal "example.org:80/lobster", SolarWindsAPM::Span.createHttpSpan(nil, "example.org/lobster", "example.org:80", 0, 200, 'GET', 0)
    assert_equal "example.org:80/lobster", SolarWindsAPM::Span.createHttpSpan(nil, "example.org:80/lobster", "example.org:80", 0, 200, 'GET', 0)
    assert_equal "example.org:80/", SolarWindsAPM::Span.createHttpSpan(nil, nil, "example.org:80", 0, 200, 'GET', 0)
    assert_equal "unknown", SolarWindsAPM::Span.createHttpSpan(nil, nil, nil, 0, 200, 'GET', 0)
  end
end
