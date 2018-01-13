# Welcome to the AppOpticsAPM Ruby Gem

The appoptics_apm gem provides [AppOptics APM](https://www.appoptics.com/) performance instrumentation for Ruby.

![Ruby AppOpticsAPM](http://www.appoptics.com/images/ruby_readme/oboe-ruby-header.png)

It has the ability to report performance metrics on an array of libraries, databases and frameworks such as Rails, Mongo, Memcache, ActiveRecord, Cassandra, Rack, Resque [and more](http://docs.appoptics.solarwinds.com/Instrumentation/ruby.html#ruby-support-matrix).

It requires an [AppOptics](https://www.appoptics.com/) account to view metrics.  Get yours, [it's free](https://https://my.appoptics.com/sign_up).

[![Gem Version](https://badge.fury.io/rb/appoptics.png)](https://badge.fury.io/rb/appoptics)
[![Build Status](https://travis-ci.org/tracelytics/ruby-appoptics.png?branch=master)](https://travis-ci.org/tracelytics/ruby-appoptics)
[![Code Climate](https://codeclimate.com/github/tracelytics/ruby-appoptics.png)](https://codeclimate.com/github/tracelytics/ruby-appoptics)

_Note: The repository name has been changed to ruby-appoptics.  Please update your github remotes with `git remote set-url origin git@github.com:tracelytics/ruby-appoptics.git`._

# Installation

_Before installing the gem below, make sure that you have the [dependencies](http://docs.appoptics.com/kb/apm_tracing/ruby/install#dependencies) installed on your host first._

The appoptics_apm gem is [available on Rubygems](https://rubygems.org/gems/appoptics_apm) and can be installed with:

```bash
gem install appoptics_apm
```

or added to _the end_ of your bundle Gemfile and running `bundle install`:

```ruby
gem 'appoptics_apm'
```

## if you're dogfooding:
Get the gem
```
source 'https://73bf9c35xxxxxxxxxxb4d26c3:@packagecloud.io/AppOptics/apm-instrumentation/' do
  gem 'appoptics_apm', '>= 4.0.0'
end
```
Set the env to report to staging (your_app_name can be any string, it is only used as name in the services list):
```
unset APPOPTICS_TRUSTEDPATH
export APPOPTICS_COLLECTOR=collector-stg.appoptics.com
export APPOPTICS_SERVICE_KEY=795fb4947d15275d208c49cfd2412d4a5bf38742045b47236c94c4fe5f5b17c7:<your_app_name>
```
If you're reporting to production, only set `APPOPTICS_SERVICE_KEY`

# Running

## Rails

![Ruby on Rails](http://docs.appoptics.com/kb/apm_tracing/ruby)

No special steps are needed to instrument Ruby on Rails.  Once part of the bundle, the appoptics gem will automatically detect Rails and instrument on stack initialization.

*Note: You will still need to decide on your `tracing_mode` depending on whether you are running with an instrumented Apache or nginx in front of your Rails stack.  See below for more details.*

### The Install Generator

The appoptics_apm gem provides a Rails generator used to seed an initializer where you can configure and control `tracing_mode` and [other options](http://docs.appoptics.com/kb/apm_tracing/ruby/configure).

To run the install generator run:

```bash
bundle exec rails generate appoptics:install
```

After the prompts, this will create an initializer: `config/initializers/appoptics.rb`.

## Sinatra

![Sinatra](http://docs.appoptics.solarwinds.com/images/ruby_readme/sinatra.png)

You can instrument your Sinatra application by adding the following code to your `config.ru` Rackup file:

```ruby
# If you're not using Bundler.require.  Make sure this is done
# after the Sinatra require directive.
require 'appoptics_apm'

AppOpticsAPM
AppOpticsAPM
```

Make sure that the appoptics_apm gem is loaded _after_ Sinatra either by listing `gem 'appoptics_apm'` after Sinatra in your Gemfile or calling the `require 'appoptics_gem'` directive after Sinatra is loaded.

With this, the appoptics_apm gem will automatically detect Sinatra on boot and instrument key components.

## Padrino

![Padrino](http://docs.appoptics.solarwinds.com/images/ruby_readme/padrino.png)

As long as the appoptics_apm gem is in your `Gemfile` (inserted after the `gem 'padrino'` directive) and you are calling `Bundler.require`, the appoptics_apm gem will automatically instrument Padrino applications.

If you need to set `AppOpticsAPM::Config` values on stack boot, you can do so by adding the following
to your `config/boot.rb` file:

```ruby
Padrino.before_load do
  # Verbose output of instrumentation initialization
  AppOpticsAPM
end
```

## Grape

![Grape](http://docs.appoptics.solarwinds.com/images/ruby_readme/grape.png)

You can instrument your Grape application by adding the following code to your `config.ru` Rackup file:

```ruby
    # If you're not using Bundler.require.  Make sure this is done
    # after the Grape require directive.
    require 'appoptics_apm'

    ...

    class App < Grape::API
      use AppOpticsAPM::Rack
    end
```

Make sure that the appoptics gem is loaded _after_ Grape either by listing `gem 'appoptics_apm'` after Grape in your Gemfile or calling the `require 'appoptics_apm'` directive after Grape is loaded.

You must explicitly tell your Grape application to use AppOpticsAPM::Rack for tracing to occur.

## Custom Ruby Scripts & Applications

The appoptics_apm gem has the ability to instrument any arbitrary Ruby application or script.

```ruby
require 'rubygems'
require 'bundler'

Bundler.require

require 'appoptics_apm'
```

From here, you can use the Tracing API to instrument areas of code using `AppOpticsAPM::API.start_trace` (see below).  If you prefer to instead dive directly into code, take a look at [this example](https://gist.github.com/pglombardo/8550713) of an instrumented Ruby script.

Once inside of the `AppOpticsAPM::API.start_trace` block, performance metrics will be automatically collected for all supported libraries and gems (Redis, Mongo, ActiveRecord etc..).

# Custom Tracing

You can add even more visibility into any part of your application or scripts by adding custom instrumentation.  If you want to see the performance of an existing method see Method Profiling.  To trace blocks of code see the Tracing API.

## The Tracing API

You can instrument any arbitrary block of code using `AppOpticsAPM::API.trace`.  The code and any supported calls for libraries that we support, will automatically get traced and reported to your dashboard.

```ruby
# layer_name will show up in the AppOptics app dashboard
layer_name = 'subsystemX'

# report_kvs are a set of information Key/Value pairs that are sent to
# AppOptics dashboard along with the performance metrics. These KV
# pairs are used to report request, environment and/or client specific
# information.

report_kvs = {}
report_kvs[:mykey] = @client.id

AppOpticsAPM::API.trace(layer_name, report_kvs) do
  # the block of code to be traced
end
```

`AppOpticsAPM::API.trace` is used within the context of a request.  It will follow the upstream state of the request being traced.  i.e. the block of code will only be traced when the parent request is being traced.

This tracing state of a request can also be queried by using `AppOpticsAPM.tracing?`.

If you need to instrument code outside the context of a request (such as a cron job, background job or an arbitrary ruby script), use `AppOpticsAPM::API.start_trace` instead which will initiate new traces based on configuration and probability (based on the sample rate).

Find more details in the [RubyDoc page](http://rdoc.info/gems/appoptics/AppOpticsAPM/API/Tracing) or in [this example](https://gist.github.com/pglombardo/8550713) on how to use the Tracing API in an independent Ruby script.

## Tracing Methods

With AppOptics, you can profile any method in your application or even in the Ruby language using `AppOpticsAPM::API.profile_method`.

If, for example, you wanted to see the performance for the `Array::sort`, you could simply call the following in your startup code:

```
AppOpticsAPM::API.profile_method(Array, :sort)
```

For full documentation, options and reporting custom KVs, see our documentation on [method profiling](http://docs.appoptics.solarwinds.com/Instrumentation/ruby.html#ruby-function-profiling).

# Support

If you find a bug or would like to request an enhancement, feel free to file an issue.  For all other support requests, see our [support portal](https://tracelytics.freshdesk.com).

# Contributing

You are obviously a person of great sense and intelligence.  We happily appreciate all contributions to the appoptics gem whether it is documentation, a bug fix, new instrumentation for a library or framework or anything else we haven't thought of.

We welcome you to send us PRs.  We also humbly request that any new instrumentation submissions have corresponding tests that accompany them.  This way we don't break any of your additions when we (and others) make changes after the fact.

## Developer Resources

We have made a large effort to expose as much technical information as possible to assist developers wishing to contribute to the appoptics gem.  Below is a good source for information and help for developers:

* The [AppOptics Knowledge Base](https://docs.appoptics.com/kb/apm_tracing) has a large collection of technical articles or, if needed, you can submit a support request directly to the team.

If you have any questions or ideas, don't hesitate to contact us anytime.

## Layout of the Gem

The appoptics gem uses a standard gem layout.  Here are the notable directories.

    lib/appoptics/inst               # Auto load directory for various instrumented libraries
    lib/appoptics/frameworks         # Framework instrumentation directory
    lib/appoptics/frameworks/rails   # Files specific to Rails instrumentation
    lib/rails                        # A Rails required directory for the Rails install generator
    lib/api                          # The AppOpticsAPM Tracing API: layers, logging, profiling and tracing
    ext/oboe_metal                   # The Ruby c extension that links against the system liboboe library

## Building the Gem

The appoptics gem is built with the standard `gem build` command passing in the gemspec:

```bash
gem build appoptics_apm.gemspec
```

## Writing Custom Instrumentation

Custom instrumentation for a library, database or other service can be authored fairly easily.  Generally, instrumentation of a library is done by wrapping select operations of that library and timing their execution using the AppOpticsAPM Tracing API which then reports the metrics to the users' AppOptics dashboard.

Here, I'll use a stripped down version of the Dalli instrumentation (`lib/appoptics/inst/dalli.rb`) as a quick example of how to instrument a client library (the dalli gem).

The Dalli gem nicely routes all memcache operations through a single `perform` operation.  Wrapping this method allows us to capture all Dalli operations called by an application.

First, we define a module (AppOpticsAPM::Inst::Dalli) and our own custom `perform_with_appoptics` method that we will use as a wrapper around Dalli's `perform` method.  We also declare an `included` method which automatically gets called when this module is included by another.  See ['included' Ruby reference documentation](https://www.omniref.com/ruby/2.2.1/symbols/Module/included).

```ruby
module AppOpticsAPM
  module Inst
    module Dalli
      include AppOpticsAPM::API::Memcache

      def self.included(cls)
        cls.class_eval do
          if ::Dalli::Client.private_method_defined? :perform
            alias perform_without_appoptics perform
            alias perform perform_with_appoptics
          end
        end
      end

      def perform_with_appoptics(*all_args, &blk)
        op, key, *args = *all_args

        if AppOpticsAPM.tracing?
          opts = {}
          opts[:KVOp] = op
          opts[:KVKey] = key

          AppOpticsAPM::API.trace('memcache', opts || {}) do
            result = perform_without_appoptics(*all_args, &blk)
            if op == :get and key.class == String
                AppOpticsAPM::API.log('memcache', 'info', { :KVHit => memcache_hit?(result) })
            end
            result
          end
        else
          perform_without_appoptics(*all_args, &blk)
        end
      end
    end
  end
end
```

Second, we tail onto the end of the instrumentation file a simple `::Dalli::Client.module_eval` call to tell the Dalli module to include our newly defined instrumentation module.  Doing this will invoke our previously defined `included` method.

```ruby
if defined?(Dalli) and AppOpticsAPM::Config[:dalli][:enabled]
  ::Dalli::Client.module_eval do
    include AppOpticsAPM::Inst::Dalli
  end
end
```

Third, in our wrapper method, we capture the arguments passed in, collect the operation and key information into a local hash and then invoke the `AppOpticsAPM::API.trace` method to time the execution of the original operation.

The `AppOpticsAPM::API.trace` method calls Dalli's native operation and reports the timing metrics and your custom `report_kvs` up to AppOptics servers to be shown on the user's dashboard.

Some other tips and guidelines:

* You can point your Gemfile directly at your cloned appoptics gem source by using `gem 'appoptics', :path => '/path/to/ruby-appoptics'`

* If instrumenting a library, database or service, place your new instrumentation file into the `lib/appoptics/inst/` directory.  From there, the appoptics gem will detect it and automatically load the instrumentation file.

* If instrumenting a new framework, place your instrumentation file in `lib/appoptics/frameworks`.  Refer to the Rails instrumentation for on ideas on how to load the appoptics gem correctly in your framework.

* Review other existing instrumentation similar to the one you wish to author.  `lib/appoptics/inst/` is a great place to start.

* Depending on the configured `:sample_rate`, not all requests will be traced.  Use `AppOpticsAPM.tracing?` to determine of this is a request that is being traced.

* Performance is paramount.  Make sure that your wrapped methods don't slow down users applications.

* Include tests with your instrumentation.  See `test/instrumentation/` for some examples of existing instrumentation tests.

## Compiling the C extension

The appoptics gem utilizes a C extension to interface with a core library bundled in with the gem which handles reporting the trace and performance data back to AppOptics servers.

C extensions are usually built on `gem install` but when working out of a local git repository, it's required that you manually build this C extension for the gem to function.

To make this simpler, we've included a few rake tasks to automate this process:

```bash
rake compile             # Build the gem's c extension
rake distclean           # Remove all built files and extensions
rake recompile           # Rebuild the gem's c extension
```

To see the code related to the C extension, take a look at `ext/oboe_metal/extconf.rb` for details.

You can read more about Ruby gems with C extensions in the [Rubygems Guides](http://guides.rubygems.org/gems-with-extensions/).

## Running the Tests

![AppOpticsAPM Ruby Tests](http://docs.appoptics.solarwinds.com/images/ruby_readme/tv_ruby_tests.png)

The tests bundled with the gem are implemented using [Minitest](https://github.com/seattlerb/minitest).  The tests are currently used to validate the sanity of the traces generated and basic gem functionality.

After a bundle install, the tests can be run as:

```bash
bundle exec rake test
```

This will run a full end-to-end test suite that covers all supported libraries and databases.  Note that this requires all of the supported software (Cassandra, Memcache, Mongo etc.) to be installed, configured and available.

Since this is overly burdensome for casual users, you can run just the tests that you're interested in.

To run just the tests for the dalli gem trace validation:

```bash
bundle exec rake test TEST=test/instrumentation/dalli_test.rb
```

We humbly request that any submitted instrumentation is delivered with corresponding test coverage.

# License

Copyright (c) 2018 SolarWinds, LLC

Released under the [Librato Open License](http://docs.appoptics.solarwinds.com/Instrumentation/librato-open-license.html)
