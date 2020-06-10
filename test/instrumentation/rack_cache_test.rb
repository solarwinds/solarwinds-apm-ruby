# Copyright (c) 2020 SolarWinds, LLC.
# All rights reserved

require "minitest_helper"

require File.expand_path(File.dirname(File.dirname(__FILE__)) + '/frameworks/apps/sinatra_simple')

describe Rack::Cache do
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  before do
    clear_all_traces
  end

  it 'creates a rack cache transaction name' do
    get "/cache"
    get "/cache"

    traces = get_all_traces

    assert_equal 'rack-cache.memcached', traces.last['TransactionName']
  end
end
