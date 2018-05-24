# Copyright (c) 2017 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require 'rack/test'
require 'rack/handler/puma'
require 'appoptics_apm/inst/rack'
require 'mocha/minitest'

describe AppOpticsAPM::API::Logging do
  describe "when we trace with a context" do
    before do
      AppOpticsAPM::Context.fromString('2BA462ADE6CFE479081764CC476AA983351DC51B1BCB3468DA6F06EEFA01')
    end

    it "should respect the request_opt parameter" do
      AppOpticsAPM::API.expects(:log_event).twice
      AppOpticsAPM::API.trace(:test, {}, 'test') do
        AppOpticsAPM::API.trace(:test, {}, 'test') do
          # no need to do anything here :)
        end
      end
    end

    it "should work without request_opt parameter" do
      AppOpticsAPM::API.expects(:log_event).times 4
      AppOpticsAPM::API.trace(:test, {}) do
        AppOpticsAPM::API.trace(:test, {}) do
          # no need to do anything here :)
        end
      end
    end
  end
end
