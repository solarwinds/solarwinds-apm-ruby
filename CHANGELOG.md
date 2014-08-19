# oboe 2.7.0 (08/13/2014)

This minor release includes:

* [JRuby instrumentation](https://github.com/appneta/oboe-ruby/pull/51) is back and better than ever
* [Updated moped instrumentation](https://github.com/appneta/oboe-ruby/pull/63) to support moped v2 changes
* Simplify start_trace by setting a default param: [#67](https://github.com/appneta/oboe-ruby/pull/67)

Pushed to Rubygems: https://rubygems.org/gems/oboe/versions/2.7.0

# oboe 2.6.8 (07/31/2014)

This patch release includes:

* Fix [instrumentation load for Padrino in test environments](https://github.com/appneta/oboe-ruby/pull/65)
* [Add delay](https://github.com/appneta/oboe-ruby/pull/66) in test suite to allow downloading of sample rate info

Pushed to Rubygems: https://rubygems.org/gems/oboe/versions/2.6.8

# oboe 2.6.7.1 (07/23/2014)

This patch release includes better error handling, API clean-up and RUM template improvements.

* [Add RUM helpers](https://github.com/appneta/oboe-ruby/pull/56) for Sinatra and Padrino stacks.  Thanks @tlunter!
* Prefer [StandardError over Exception](https://github.com/appneta/oboe-ruby/pull/59) for rescue blocks that we handle directly
* [Clean up Oboe logging API](https://github.com/appneta/oboe-ruby/pull/58): Oboe.log, Oboe::Context.log and Oboe::API.log redundancy

# oboe 2.6.6.1 (06/16/2014)

This patch release adds new instrumentation and a couple fixes:

* [Add instrumentation support](https://github.com/appneta/oboe-ruby/pull/37) for [Grape API Micro Framework](http://intridea.github.io/grape/) (thanks @tlunter!)
* Important [Mongo find operation with block fix](https://github.com/appneta/oboe-ruby/pull/53) (thanks @rafaelfranca!)
* Better and more [data independent tests](https://github.com/appneta/oboe-ruby/pull/52) for Travis

# oboe 2.6.5.5 (06/02/2014)

This patch release improves [instrumentation for Mongo](https://github.com/appneta/oboe-ruby/pull/48) version >= 1.10 and fixes TraceView [sample rate reporting](https://github.com/appneta/oboe-ruby/pull/50).

# oboe 2.6.4.1 (04/30/2014)

This patch release adds detection and support for Redhat [OpenShift](https://www.openshift.com/).  See our OpenShift [TraceView cartridge](https://github.com/appneta/openshift-cartridge-traceview) for base libraries before using this gem on OpenShift.

# oboe 2.6.3.0 (04/07/2014)

This patch releases fixes a number of smaller issues:

* the gem will no longer start traces on static assets (https://github.com/appneta/oboe-ruby/pull/31)
* fix occasionally broken `profile_name` values when using [custom method tracing](https://github.com/appneta/oboe-ruby#tracing-methods)
* fix for incorrectly starting traces when in `through` tracing mode under certain circumstances
* Expand the test suite to validate sample rates and tracing modes (https://github.com/appneta/oboe-ruby/pull/8)

# oboe 2.6.2.0 (03/24/2014)

* This patch release improves webserver detection on Heroku and adds in some c extension protections.  A oboe-heroku gem release will follow this release.

# oboe 2.6.1.0 (03/12/2014)

This is a patch release to address "Unsupported digest algorithm (SHA256)" occurring under certain cases on Heroku. A oboe-heroku gem release will follow this release.

* Support delayed Reporter Initialization for Forking Webservers
* README syntax fixes

# oboe 2.5.0.7 (02/2013/2014)

* Added new Redis redis-rb gem (>= 3.0.0) instrumentation
* Fix a SampleSource bitmask high bit issue
* Expanded __Init reports
* Fix Ruby standalone returning nil X-Trace headers (1B000000...)
* Test against Ruby 2.1.0 on TravisCI
* Fix errant Oboe::Config warning

# oboe 2.4.0.1 (01/12/2013)

* Report SampleRate & SampleSource per updated SWIG API
* Change OboeHeroku __Init Key 
* Remove oboe_fu artifacts
* CodeClimate Initiated improvements
* Remove SSL connection requirement from Net::HTTP tests
* oboe.gemspec doesn't specify Ruby 1.8 json dependency
* add config to blacklist tracing of actions (thanks @nathantsoi!)
* Report the application server used
* Support Oboe::Config.merge! and warn on non-existent (thanks @adamjt!)

# oboe 2.3.4.1 (11/21/2013)

* Stacks that use a caching system like Varnish could see corrupted traces; fixed. 

# oboe 2.3.3.7 (11/06/2013)

* Rename the _Init layer to "rack"
* Decode URLS when reporting them
* Resque layer naming split into 1) client queuing of a job: 'resque-client', 2) Resque worker running a job: 'resque-worker'
* Fix for an extension load error and some refactoring of functionality into a base module (OboeBase)
* Improved and more resilient method profiling
* Further refactoring for Ruby 2.0 support
* Track the version of the instrumentation installed

# oboe 2.3.2 (10/22/2013)

* Backtrace collection can now be configured to skip certain components if a lighter-weight trace is desired
* On MRI Ruby the hostname of the Tracelyzer is now configurable via Oboe::Config[:reporter_host] (default is localhost)
* Fix to MongoDb query identification
* Event building in the Rack layer optimized
* Renamed "sampling_rate" to be "sample_rate" for consistency
* More tests added and documentation in anticipation of our Ruby open-source initiative

# oboe 2.2.6 (09/27/2013)

* Query Privacy now fully supported; can configure the app to not send SQL parameters if needed
* Configuring the local sample rate now supports 1e6 notation
* Improved log messaging if a gem dependency is missing
* Now reporting HTTPStatus on http client calls
* Heroku - the start time when a request hits the load balancer now captured

# oboe 2.2.0 (09/12/2013)

* Initial support for Rails 4
* Various internal reporting fixes and improvements
* Fix for auto sampling rate

# oboe 2.1.4 (08/01/2013)

* Integration support for AppView Web

# oboe 2.1.3 (07/16/2013)

* Allow _Access Key_ assignment via Environment variable: TRACEVIEW_CUUID

# oboe 2.1.1

* The gem now logs via a standard Ruby logger: Oboe.logger
* Add in rspec tests
* JRuby now supports Smart Tracing
* Fixed an invalid Profile name in ActionView Partial tracing

# oboe 1.4.2.2

* Rack - add handling for potential nil result

# oboe 1.4.2

* Cassandra - ensure all keys are captured when reporting exceptions
* JRuby detection fix

# oboe 1.4.1.2

* HTTP keys now captured at Rack level instead of Rails
* RUM templates are now pre-loaded
* Improved layer agnostic info event reporting

# oboe 1.4.0.2

* Resque support
* Fix Rails 2 bug where SET and SHOW could result in recursive calls
* Memcache - multi-get calls now report a total for number of keys and number 
of hits
* Configuration - added ability to identify components to skip from 
instrumentation
* Configuration - sending Resque parameters can be skipped if privacy an issue.

# oboe 1.3.9.1

* Add in Rack instrumentation
* Fix Function profiling of class methods bug
* Add backtraces to Cassandra and Mongo operations
* Rename the "render" layer to "actionview"

# oboe 1.3.8

* More comprehensive JRuby support

# oboe 1.3.7

* Added Moped driver instrumentation (Mongo/Mongoid)

# oboe 1.3.6

* Added Rails ActionView partial and collection rendering instrumentation

# oboe 1.3.5

* Added cassandra instrumentation

# oboe 1.3.4

* Added mongo-ruby-driver support

# oboe 1.3.3

* Updated RUM instrumentation templates

# oboe 1.3.2

* Fix a case when the RUM instrumentation header/footer methods would not 
return JS output, depending on how the way they were called from HAML.

# oboe 1.3.1

* Support for RUM instrumentation.
Fix for certain cases where exceptions were not properly propagated up to Rails 
error handlers.

# oboe 1.3.0

* The oboe and oboe_fu gems have been merged to simplify installation. The 
final oboe_fu gem (1.3.0) simply calls "require 'oboe'" now for backwards 
compatibility.
* Please note our updated installation instructions for the new location of 
Ruby oboe API methods.
* Our gem now successfully installs even if your platform does not have our 
base packages (liboboe) installed, so you can deploy to environments with or 
without TraceView support.

# oboe_fu 1.2.1

* Support for instrumenting the dalli module.

# oboe_fu 1.2.0

* Support for Rails 2.3, 3.0, 3.1, and 3.2.


