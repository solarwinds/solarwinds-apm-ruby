# Welcome to the SolarWindsAPM Ruby Gem

The solarwinds_apm gem provides [SolarWindsAPM](https://www.appoptics.com/) performance instrumentation for Ruby.

It has the ability to report performance metrics on an array of libraries, databases and frameworks such as Rails,
Rack, ActiveRecord, Mongo, Memcache, Resque 
[and more](https://docs.appoptics.com/kb/apm_tracing/ruby/support-matrix/).

It requires an [Solarwinds] account to view metrics.  Get yours, 
[it's free](https://my.appoptics.com/sign_up).

[![Gem Version](https://badge.fury.io/rb/solarwinds_apm.svg)](https://badge.fury.io/rb/solarwinds_apm)

[![Run all Tests](https://github.com/appoptics/appoptics-apm-ruby/actions/workflows/run_tests.yml/badge.svg)](https://github.com/appoptics/appoptics-apm-ruby/actions/workflows/run_tests.yml)
[![C++ Tests](https://github.com/appoptics/appoptics-apm-ruby/actions/workflows/run_cpluplus_tests.yml/badge.svg)](https://github.com/appoptics/appoptics-apm-ruby/actions/workflows/run_cpluplus_tests.yml)

[comment]: <> ([![Maintainability]&#40;https://api.codeclimate.com/v1/badges/ac7f36241a23a3a82fc5/maintainability&#41;]&#40;https://codeclimate.com/github/appoptics/appoptics-apm-ruby/maintainability&#41;)

# Documentation

* [SolarWindsAPM Knowledge Base](https://docs.appoptics.com/kb/apm_tracing/ruby)

# Installation

_Before installing the gem below, make sure that you have the 
[dependencies](http://docs.appoptics.com/kb/apm_tracing/ruby/install#dependencies) installed on your host first._

The solarwinds_apm gem is [available on Rubygems](https://rubygems.org/gems/solarwinds_apm) and can be installed with:

```bash
gem install solarwinds_apm
```

or added to **the end** of your Gemfile and running `bundle install`:

```ruby
gem 'solarwinds_apm'
```

# Running

Make sure to set `SW_APM_SERVICE_KEY` in the environment from where the app or service is run, e.g:
```
export SW_APM_SERVICE_KEY=795fb4947d15275d208c49cfd2412d4a5bf38742045b47236c94c4fe5f5b17c7:<your_app_name>
```

## Rails

![Ruby on Rails](https://docs.appoptics.com/_images/rails.png)

No special steps are needed to instrument Ruby on Rails.  Once part of the bundle, the solarwinds-apm gem will automatically 
detect Rails and instrument on stack initialization.

### The Install Generator

The solarwinds_apm gem provides a Rails generator used to seed an initializer where you can configure and control 
`tracing_mode` and [other options](http://docs.appoptics.com/kb/apm_tracing/ruby/configure).

To run the install generator run:

```bash
bundle exec rails generate solarwinds_apm:install
```

After the prompts, this will create an initializer: `config/initializers/solarwinds_apm.rb`.

## Sinatra

![Sinatra](https://docs.appoptics.com/_images/sinatra.png)

You can instrument your Sinatra application by adding the following code to your `config.ru` Rackup file:

```ruby
# If you're not using Bundler.require.  Make sure this is done
# after the Sinatra require directive.
require 'solarwinds_apm'
```

Make sure that the solarwinds_apm gem is loaded _after_ Sinatra either by listing `gem 'solarwinds_apm'` after Sinatra in 
your Gemfile or calling the `require 'solarwinds_gem'` directive after Sinatra is loaded.

With this, the solarwinds_apm gem will automatically detect Sinatra on boot and instrument key components.

## Padrino

![Padrino](https://docs.appoptics.com/_images/padrino.svg)

As long as the solarwinds_apm gem is in your `Gemfile` (inserted after the `gem 'padrino'` directive) and you are calling 
`Bundler.require`, the solarwinds_apm gem will automatically instrument Padrino applications.

If you need to set `SolarWindsAPM::Config` values on stack boot, you can do so by adding the following
to your `config/boot.rb` file:

```ruby
Padrino.before_load do
  # Verbose output of instrumentation initialization
  SolarWindsAPM
end
```

## Grape

![Grape](https://docs.appoptics.com/_images/grape.png)

You can instrument your Grape application by adding the following code to your `config.ru` Rackup file:

```ruby
    # If you're not using Bundler.require.  Make sure this is done
    # after the Grape require directive.
    require 'solarwinds_apm'

    ...

    class App < Grape::API
      use SolarWindsAPM::Rack
    end
```

Make sure that the solarwinds gem is loaded _after_ Grape either by listing `gem 'solarwinds_apm'` after Grape in your 
Gemfile or calling the `require 'solarwinds_apm'` directive after Grape is loaded.

You must explicitly tell your Grape application to use SolarWindsAPM::Rack for tracing to occur.


# SDK for Custom Tracing 

The solarwinds_apm gem has the ability to instrument any arbitrary Ruby application or script.

```ruby
require 'rubygems'
require 'bundler'

Bundler.require

require 'solarwinds_apm'
```

You can add even more visibility into any part of your application or scripts by adding custom instrumentation.  

## SolarWindsAPM::SDK.trace
You can instrument any arbitrary block of code using `SolarWindsAPM::SDK.trace`.  

```ruby
# layer_name will show up in the SolarWinds dashboard
layer_name = 'subsystemX'

# report_kvs are a set of information Key/Value pairs that are sent to
# SolarWinds dashboard along with the performance metrics. These KV
# pairs are used to report request, environment and/or client specific
# information.

report_kvs = {}
report_kvs[:mykey] = @client.id

SolarWindsAPM::SDK.trace(layer_name, kvs: report_kvs) do
  # the block of code to be traced
end
```

`SolarWindsAPM::SDK.trace` is used within the context of a request.  It will follow the upstream state of the request 
being traced.  i.e. the block of code will only be traced when the parent request is being traced.

This tracing state of a request can also be queried by using `SolarWindsAPM.tracing?`.

## SolarWindsAPM::SDK.start_trace

If you need to instrument code outside the context of a request (such as a cron job, background job or an arbitrary 
ruby script), use `SolarWindsAPM::SDK.start_trace` instead which will initiate a new trace based on configuration and 
probability (based on the sample rate).



### Example

```ruby
require 'rubygems'
require 'bundler'

Bundler.require

# Make sure solarwinds_apm is at the bottom of your Gemfile.
# This is likely redundant but just in case.
require 'solarwinds_apm'
 

# Tracing mode can be :enabled or :disabled
SolarWindsAPM::Config[:tracing_mode] = :enabled
 
#
# Update April 9, 2015 - this is done automagically now
# and doesn't have to be called manually
#
# Load library instrumentation to auto-capture stuff we know about...
# e.g. ActiveRecord, Cassandra, Dalli, Redis, memcache, mongo
# TraceView::Ruby.load
 
# Some KVs to report to the dashboard
report_kvs = {}
report_kvs[:command_line_params] = ARGV.to_s
report_kvs[:user_id] = `whoami`
 
SolarWindsAPM::SDK.start_trace('my_background_job', kvs: report_kvs) do
  #
  # Initialization code
  #
  
  tasks = get_all_tasks
  
  tasks.each do |t|
    # Optional: Here we embed another 'trace' to separate actual 
    # work for each task.  In the traces dashboard this will show 
    # up as a large 'my_background_job' parent layer with many 
    # child 'task' layers.
    SolarWindsAPM::SDK.trace('task', kvs: { :task_id => t.id }) do
      t.perform
    end
  end
  
  #
  # cleanup code
  #
end
 

# Note that we use 'start_trace' in the outer block and 'trace' for
# any sub-blocks of code we wish to instrument.  The arguments for
# both methods vary slightly. 
``` 

Find more details in the [RubyDoc page](https://www.rubydoc.info/gems/solarwinds_apm/SolarWindsAPM/SDK) on how to use the Tracing SDK in an independent Ruby script.

# Support

If you run into a problem, find a bug, or would like to request an enhancement, feel free to contact our tech support 
[technicalsupport@solarwinds.com](technicalsupport@solarwinds.com).  

# Contributing

You are obviously a person of great sense and intelligence.  We happily appreciate all contributions to the solarwinds_apm 
gem whether it is documentation, a bug fix, new instrumentation for a library or framework or anything else we haven't 
thought of.

We welcome you to send us PRs.  We also humbly request that any new instrumentation submissions have corresponding tests 
that accompany them.  This way we don't break any of your additions when we (and others) make changes after the fact.


## Layout of the Gem

The solarwinds_apm gem uses a standard gem layout.  Here are the notable directories.

    lib/solarwinds_apm/inst               # Auto load directory for various instrumented libraries
    lib/solarwinds_apm/frameworks         # Framework instrumentation directory
    lib/solarwinds_apm/frameworks/rails   # Files specific to Rails instrumentation
    lib/rails                             # A Rails required directory for the Rails install generator
    lib/api                               # The SolarWindsAPM Tracing API: layers, logging, tracing
    ext/oboe_metal                        # The Ruby c extension that links against the system liboboe library

## Building the Gem

The solarwinds_apm gem is built with the standard `gem build` command passing in the gemspec:

```bash
gem build solarwinds_apm.gemspec
```

## Writing Custom Instrumentation

Custom instrumentation for a library, database or other service can be authored fairly easily.  Generally, 
instrumentation of a library is done by wrapping select operations of that library and timing their execution using the 
SolarWindsAPM Tracing SDK which then reports the metrics to the users' SolarWinds dashboard.

Here, I'll use a stripped down version of the Dalli instrumentation (`lib/solarwinds_apm/inst/dalli.rb`) as a quick example 
of how to instrument a client library (the dalli gem).

The Dalli gem nicely routes all memcache operations through a single `perform` operation.  Wrapping this method allows 
us to capture all Dalli operations called by an application.

First, we define a module (SolarWindsAPM::Inst::Dalli) and our own custom `perform_with_sw_apm` method that we will 
use as a wrapper around Dalli's `perform` method.  We also declare an `included` method which automatically gets called 
when this module is included by another.  
See [`Module#included` Ruby reference documentation](https://devdocs.io/ruby~2.5/module#method-i-included).

```ruby
module SolarWindsAPM
  module Inst
    module Dalli
      include SolarWindsAPM::API::Memcache
 
      def self.included(cls)
        cls.class_eval do
          if ::Dalli::Client.private_method_defined? :perform
            alias perform_without_sw_apm perform
            alias perform perform_with_sw_apm
          end
        end
      end
 
      def perform_with_sw_apm(*all_args, &blk)
        op, key, *args = *all_args
 
        if SolarWindsAPM.tracing?
          opts = {}
          opts[:KVOp] = op
          opts[:KVKey] = key
 
          SolarWindsAPM::SDK.trace('memcache', kvs: opts) do
            result = perform_without_sw_apm(*all_args, &blk)
            if op == :get and key.class == String
                SolarWindsAPM::API.log_info('memcache', { :KVHit => memcache_hit?(result) })
            end
            result
          end
        else
          perform_without_sw_apm(*all_args, &blk)
        end
      end
       
    end
  end
end
```

Second, we tail onto the end of the instrumentation file a simple `::Dalli::Client.module_eval` call to tell the Dalli 
module to include our newly defined instrumentation module.  Doing this will invoke our previously defined `included` method.

```ruby
if defined?(Dalli) and SolarWindsAPM::Config[:dalli][:enabled]
  ::Dalli::Client.module_eval do
    include SolarWindsAPM::Inst::Dalli
  end
end
```

Third, in our wrapper method, we capture the arguments passed in, collect the operation and key information into a local 
hash and then invoke the `SolarWindsAPM::SDK.trace` method to time the execution of the original operation.

The `SolarWindsAPM::SDK.trace` method calls Dalli's native operation and reports the timing metrics and your custom 
`report_kvs` up to SolarWinds servers to be shown on the user's dashboard.

Some other tips and guidelines:

* You can point your Gemfile directly at your cloned solarwinds_apm gem source by using 
`gem 'solarwinds_apm', :path => '/path/to/ruby-solarwinds'`

* If instrumenting a library, database or service, place your new instrumentation file into the `lib/solarwinds_apm/inst/` 
directory.  From there, the solarwinds_apm gem will detect it and automatically load the instrumentation file.

* If instrumenting a new framework, place your instrumentation file in `lib/solarwinds_apm/frameworks`.  Refer to the Rails 
instrumentation for on ideas on how to load the solarwinds_apm gem correctly in your framework.

* Review other existing instrumentation similar to the one you wish to author.  `lib/solarwinds_apm/inst/` is a great place 
to start.

* Depending on the configured `:sample_rate`, not all requests will be traced.  Use `SolarWindsAPM.tracing?` to determine 
of this is a request that is being traced.

* Performance is paramount.  Make sure that your wrapped methods don't slow down users applications.

* Include tests with your instrumentation.  See `test/instrumentation/` for some examples of existing instrumentation 
tests.

## Compiling the C extension

The solarwinds_apm gem utilizes a C extension to interface with a core library bundled in with the gem which handles 
reporting the trace and performance data back to SolarWinds servers.

C extensions are usually built on `gem install` but when working out of a local git repository, it's required that you 
manually build this C extension for the gem to function.

To make this simpler, we've included a few rake tasks to automate this process:

```bash
rake clean               # make sure no old stuff is around
rake fetch_ext_deps      # download c-files
rake compile             # Build the gem's c extension
```

To see the code related to the C extension, take a look at `ext/oboe_metal/extconf.rb` for details.

You can read more about Ruby gems with C extensions in the 
[Rubygems Guides](http://guides.rubygems.org/gems-with-extensions/).

## Running the Tests

See the README in the test directory.

# License

Copyright (c) 2018 SolarWinds, LLC

Released under the [Apache License 2.0](http://www.apache.org/licenses/LICENSE-2.0)
