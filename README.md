# Welcome to the TraceView Ruby Gem! (AKA oboe)

The oboe gem provides AppNeta [TraceView](http://www.appneta.com/application-performance-management/) instrumentation for Ruby.

It has the ability to report performance metrics on an array of libraries, databases and frameworks such as Rails, Mongo, Memcache, ActiveRecord, Cassandra, Rack, Resque [and more](https://support.tv.appneta.com/support/solutions/articles/86388-ruby-instrumentation-support-matrix).

# Installation

The oboe gem is hosted on Rubygems and can be installed with:

    gem install oboe

or added to your bundle Gemfile and running `bundle install`:

    gem 'oboe'

# Running

## Rails

No special steps are needed to instrument Ruby on Rails.  The oboe gem will automatically detect Rails and instrument on stack initialization.

_Note: You will still need to decide on your `tracing_mode` depending on whether you are running with an instrumented Apache or nginx in front of your Rails stack.  See below for more details._

### The Install Generator

The oboe gem provides a Rails generator used to seed an oboe initializer where you can configure and control `tracing_mode`, `sample_rate` and other options.

To run the install generator run:

    bundle exec rails generate oboe:install

After the prompts, this will create an initializer: `config/initializers/oboe.rb`.

## Sinatra/Padrino

You can instrument your Sinatra or Padrino application by adding the following code to your `config.ru` Rackup file (Padrino example).

    require 'oboe'
    require 'oboe/inst/rack'
    
    # When traces should be initiated for incoming requests. Valid options are
    # “always,” “through” (when the request is initiated with a tracing header 
    # from upstream) and “never”. You must set this directive to “always” in 
    # order to initiate tracing.
    Oboe::Config[:tracing_mode] = 'through'
    
    # You can remove the following line in production to allow for
    # auto sampling or managing the sample rate through the TraceView portal.
    # Oboe::Config[:sample_rate] = 1000000
    
    # You may want to replace the Oboe.logger with your own
    Oboe.logger = Padrino.logger
    
    Oboe::Ruby.initialize
    Padrino.use Oboe::Rack

_In a future release of Traceview, much of this will be automated._

## Custom Ruby Scripts & Applications

The oboe gem has the ability to instrument any arbitrary Ruby application or script as long as the gem is initialized with the manual methods:

    require 'rubygems'
    require 'bundler'
    
    Bundler.require
    
    require 'oboe'
    Oboe::Ruby.initialize

From here, you can use the Tracing API to instrument areas of code.

## Other

You can send deploy notifications to TraceView and have the events show up on your dashboard.  See: [Capistrano Deploy Notifications with tlog](https://support.tv.appneta.com/support/solutions/articles/86389-capistrano-deploy-notifications-with-tlog).

# Custom Tracing

## The Tracing API

You can instrument any arbitrary block of code using the following pattern:

    # layer_name will show up in the TraceView app dashboard
    layer_name = 'subsystemX'

    # report_kvs are a set of information Key/Value pairs that are sent to TraceView along with the performance metrics.
    # These KV pairs can report on request, environment or client specific information.

    report_kvs = {}
    report_kvs[:mykey] = @client.id

    Oboe::API.trace(layer_name, report_kvs) do
      # the block of code to be traced
    end

## Tracing Methods

# Support

If you find a bug or would like to request an enhancement, feel free to file an issue.  For all other support request, see our [support portal](https://support.tv.appneta.com/).

# Contributing

Already we are boldly launched upon the deep; but soon we shall be lost in its unshored, harbourless immensities. Ere that come to pass; ere the Pequod's weedy hull rolls side by side with the barnacled hulls of the leviathan; at the outset it is but well to attend to a matter almost indispensable to a thorough appreciative understanding of the more special leviathanic revelations and allusions of all sorts which are to follow.

## Layout of the Gem

## Building the Gem

The oboe gem is built with the standard `gem build` command passing in the gemspec:

    gem build oboe.gemspec

## Writing Custom Instrumentation

## Running the Tests

The tests bundled with the gem are implemented using [Minitest](https://github.com/seattlerb/minitest).  The tests are currently used to validate the sanity of the traces generated and basic gem functionality.

After a bundle install, the tests can be run as:

    bundle exec rake test

This will run a full end-to-end test suite that covers all supported libraries and databases.  Note that this requires all of the supported software (Cassandra, Memcache, Mongo etc.) to be installed, configured and available.

Since this is overly burdonsome for casual users, you can run just the tests that you're interested in.  

To run just the tests for the dalli gem trace validation:

    bundle exec rake test TEST=test/instrumentation/dalli_test.rb

We request that any submitted instrumention is delivered with corresponding test coverage.

# License

Copyright (c) 2013 Appneta

Released under the [AppNeta Open License](http://www.appneta.com/appneta-license), Version 1.0

