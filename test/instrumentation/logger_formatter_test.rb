# Copyright (c) 2019 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'

describe "Logger::Formatter " do
  let(:msg) { Logger::Formatter.new.call('error', Time.now, 'test', 'Message.') }
  let (:exc_message) { Logger::Formatter.new.call('error', Time.now, 'test', StandardError.new) }

  load File.join(File.dirname(__FILE__), 'logger_formatter_helper.rb')
end

describe "Lumberjack::Formatter " do
  let(:msg) { Lumberjack::Formatter.new.call('error', Time.now, 'test', 'Message.') }
  let (:exc_message) { Lumberjack::Formatter.new.call('error', Time.now, 'test', StandardError.new) }

  load File.join(File.dirname(__FILE__), 'logger_formatter_helper.rb')
end

describe "Logging::LogEvent " do
  let(:msg) { Logging::LogEvent.new('error', Time.now, 'Message.', false).data }
  let (:exc_message) { Logging::LogEvent.new('error', Time.now, StandardError.new, false).data }

  load File.join(File.dirname(__FILE__), 'logger_formatter_helper.rb')
end

