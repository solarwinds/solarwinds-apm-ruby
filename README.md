# Welcome to the TraceView Ruby Gem
## AKA The oboe gem

The oboe gem provides AppNeta [TraceView](http://www.appneta.com/application-performance-management/) instrumentation for Ruby.

![Ruby TraceView](https://s3.amazonaws.com/pglombardo/oboe-ruby-header.png)

It has the ability to report performance metrics on an array of libraries, databases and frameworks such as Rails, Mongo, Memcache, ActiveRecord, Cassandra, Rack, Resque [and more](https://support.tv.appneta.com/support/solutions/articles/86388-ruby-instrumentation-support-matrix).

It requires a [TraceView](http://www.appneta.com/products/traceview/) account to view metrics.  Get yours, [it's free](http://www.appneta.com/products/traceview-free-account/).

# Installation

The oboe gem is [available on Rubygems](https://rubygems.org/gems/oboe) and can be installed with:

    gem install oboe

or added to your bundle Gemfile and running `bundle install`:

    gem 'oboe'

# Running

## Rails

No special steps are needed to instrument Ruby on Rails.  Once part of the bundle, the oboe gem will automatically detect Rails and instrument on stack initialization.

_Note: You will still need to decide on your `tracing_mode` depending on whether you are running with an instrumented Apache or nginx in front of your Rails stack.  See below for more details._

### The Install Generator

The oboe gem provides a Rails generator used to seed an oboe initializer where you can configure and control `tracing_mode`, `sample_rate` and [other options](https://support.tv.appneta.com/support/solutions/articles/86392-configuring-the-ruby-instrumentation).

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

_In a future release, much of this will be automated._

## Custom Ruby Scripts & Applications

The oboe gem has the ability to instrument any arbitrary Ruby application or script as long as the gem is initialized with the manual methods:

    require 'rubygems'
    require 'bundler'
    
    Bundler.require
    
    require 'oboe'
    Oboe::Ruby.initialize

From here, you can use the Tracing API to instrument areas of code (see below).

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

Find more details in the TraceView [documentation portal](https://support.tv.appneta.com/support/solutions/articles/86395-ruby-instrumentation-public-api).

## Tracing Methods

By using class level declarations, it's possible to automatically have certain methods on that class instrumented and reported to your TraceView dashboard automatically.

The pattern for Method Profiling is as follows:

    # 'profile_name' is similar to a layer name.  
    # It identifies this custom trace in your dashboard.
    # 
    class Engine
        include OboeMethodProfiling

        def processor()
            # body of method
        end

        # call syntax: profile_method <method>, <profile_name>
        profile_method :processor, 'processor' 
    end

This example demonstrates method profiling of instance methods.  Class methods are profiled slightly differently.  See the TraceView [documentation portal](https://support.tv.appneta.com/support/solutions/articles/86395-ruby-instrumentation-public-api) for full details.

# Support

If you find a bug or would like to request an enhancement, feel free to file an issue.  For all other support requests, see our [support portal](https://support.tv.appneta.com/) or on IRC @ #tracelytics on Freenode.

# Contributing

You are obviously a person of great sense and intelligence.  We happily apprciate all contributions to the oboe gem whether it is documentation, a bug fix, new instrumentation for a library or framework or anything else we haven't thought of.

We welcome you to send us PRs.  We also humbly request that any new instrumentation submissions have corresponding tests that accompany them.  This way we don't break any of your additions when we (and others) make changes after the fact.

If at any time, you have a question, you can reach us through our [support portal](https://support.tv.appneta.com) or on our IRC channel #tracelytics on freenode.

## Layout of the Gem

The oboe gem uses a standard gem layout.  Here are the notable directories.

    lib/oboe/inst               # Auto load directory for various instrumented libraries
    lib/oboe/frameworks         # Framework instrumentation directory
    lib/oboe/frameworks/rails   # Files specific to Rails instrumentation
    lib/rails                   # A Rails required directory for the Rails install generator
    lib/api                     # The TraceView Tracing API: layers, logging, profiling and tracing
    ext/oboe_metal              # The Ruby c extension that links against the system liboboe library

## Building the Gem

The oboe gem is built with the standard `gem build` command passing in the gemspec:

    gem build oboe.gemspec

## Writing Custom Instrumentation

Custom instrumentation for a library, database or other service can be authored fairly easily.  Generally, instrumentation of a library is done by wrapping select operations of that library and timing their execution using the Oboe Tracing API which then reports the metrics to the users' TraceView dashboard.

Here, I'll use a stripped down version of the Dalli instrumentation (`lib/oboe/inst/dalli.rb`) as a quick example of how to instrument a client library (the dalli gem).

The Dalli gem nicely routes all memcache operations through a single `perform` operation.  Wrapping this method allows us to capture all Dalli operations called by an application.

First, we define a module (Oboe::Inst::Dalli) and our own custom `perform_with_oboe` method that we will use as a wrapper around Dalli's `perform` method.  We also declare an `included` method which automatically gets called when this module is included by another.  See ['included' Ruby reference documentation](http://apidock.com/ruby/Module/included).

    module Oboe
      module Inst
        module Dalli
          include Oboe::API::Memcache

          def self.included(cls)
            cls.class_eval do
              if ::Dalli::Client.private_method_defined? :perform
                alias perform_without_oboe perform
                alias perform perform_with_oboe
              end
            end
          end
          
          def perform_with_oboe(*all_args, &blk)
            op, key, *args = *all_args

            if Oboe.tracing? and not Oboe::Context.tracing_layer_op?(:get_multi)
              opts = {}
              opts[:KVOp] = op
              opts[:KVKey] = key

              Oboe::API.trace('memcache', opts || {}) do
                result = perform_without_oboe(*all_args, &blk)
                if op == :get and key.class == String
                    Oboe::API.log('memcache', 'info', { :KVHit => memcache_hit?(result) })
                end
                result
              end
            else
              perform_without_oboe(*all_args, &blk)
            end
          end
        end
      end
    end

Second, we tail onto the end of the instrumentation file a simple `::Dalli::Client.module_eval` call to tell the Dalli module to include our newly defined instrumentation module.  Doing this will invoke our previously defined `included` method.

    if defined?(Dalli) and Oboe::Config[:dalli][:enabled]
      ::Dalli::Client.module_eval do
        include Oboe::Inst::Dalli
      end
    end

Third, in our wrapper method, we capture the arguments passed in, collect the operation and key information into a local hash and then invode the `Oboe::API.trace` method to time the execution of the original operation.

The `Oboe::API.trace` method calls Dalli's native operation and reports the timing metrics and your custom `report_kvs` up to TraceView servers to be shown on the user's dashboard.

That is a very quick example of a simple instrumentation example.  If you have any questions, visit us on IRC in #tracelytics on Freenode.

Some other tips and guidelines:

* You can point your Gemfile directly at your cloned oboe source by using `gem 'oboe', :path => '/path/to/oboe-ruby'`

* If instrumenting a library, database or service, place your new instrumentation file into the `lib/oboe/inst/` directory.  From there, the oboe gem will detect it and automatically load the instrumentation file.

* If instrumentating a new framework, place your instrumentation file in `lib/oboe/frameworks`.  Refer to the Rails instrumentation for on ideas on how to load the oboe gem correctly in your framework.

* Review other existing instrumention similar to the one you wish to author.  `lib/oboe/inst/` is a great place to start.

* Performance is paramount.  Make sure that your wrapped methods don't slow down users applications.


## Running the Tests

The tests bundled with the gem are implemented using [Minitest](https://github.com/seattlerb/minitest).  The tests are currently used to validate the sanity of the traces generated and basic gem functionality.

After a bundle install, the tests can be run as:

    bundle exec rake test

This will run a full end-to-end test suite that covers all supported libraries and databases.  Note that this requires all of the supported software (Cassandra, Memcache, Mongo etc.) to be installed, configured and available.

Since this is overly burdonsome for casual users, you can run just the tests that you're interested in.  

To run just the tests for the dalli gem trace validation:

    bundle exec rake test TEST=test/instrumentation/dalli_test.rb

We humbly request that any submitted instrumention is delivered with corresponding test coverage.

# License

Copyright (c) 2013 Appneta

Released under the [AppNeta Open License](http://www.appneta.com/appneta-license), Version 1.0

