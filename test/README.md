# README for the AppOpticsAPM Test Suite

  * [Prerequisites](#prerequisites)
    * [Linux](#linux)
    * [Services](#services)
    * [Oboe](#oboe)
  * [Defining components of a test run](#defining-components-of-a-test-run)
  * [Running Tests](#running-tests)
    * [Run all tests](#run-all-tests)
    * [Run some tests](#run-some-tests)
    * [Run one test from suite, a specific test file, or a specific test](#run-one-test-from-suite,-a-specific-test-file,-or-a-specific-test)
  * [byebug for debugging](#byebug-for-debugging)
  * [Duplication (◔_◔) and missing tests ( •̆௰•̆ )](#duplication-(◔_◔)-and-missing-tests-(-•̆௰•̆-))

The tests for this gem focus on sending the correct information
to the data collector as well as dealing with exceptions when
using the gem.

Many of them are set up in the style of integration tests and rely
on external services or background jobs.

We are providing a Docker setup that makes it easy to run test suites
and debug while writing code. The gem code is shared as a volume in the
docker container so that any changes to the code are reflected
immediately.

## Prerequisites

The following are prerequisites which will be satisfied automatically when
using the provided Docker test setup.

### Linux
The appoptics_apm gem only runs on Linux because the c-library that
sends data to the collector is only available on Linux.

Therefore the tests need to run in Linux and debugging needs to be
done in Linux.

Please see further down on how to run a single test.

### Services
The tests require different services to be running, mainly:
* mysql
* postgresql
* redis
* memcached
* rabbitmq
* mongo

### Oboe
Oboe is the c-library that provides the methods to send data to
the collector.
When using the gem from source it needs to be installed once on a
new platform:
```bash
bundle exec rake fetch_ext_deps
bundle exec rake clean
bundle exec rake compile
```
It installs automatically when using the docker test setup or the compiled gem.

## Defining components of a test run
A single test run is defined by:
* the ruby version
* the gemfile
* the database type

This means that the same tests can be run with different ruby versions
or databases. And, the selected gemfile determines which test files will be run.

See `.travis.yml` for the components of the test matrix.

## Running Tests
Since the tests need to run in Linux there is docker setup for
the Mac users and it probably makes sense for Linux users as well,
because it takes care of starting the required services.

### Run all tests
To run all tests as defined in .travs.yml:
```bash
rake docker_tests
```
>Temporarily commenting out components (e.g. a ruby version) in travis.yml
is a good way to reduce the time of a test run.

Be aware that starting the container takes longer if the Docker image needs to be created first
(+10-15 minutes) because it needs to install three versions of Ruby, which is a pretty
slow process. It is recommended to keep the appoptics_apm image and only replace
it if there is a change with the Ruby versions required for the tests.

When done with testing, the auxiliary containers can be stopped with:
```bash
rake docker_down
```

### Run some tests
In this case we want to start a docker container and then define
which tests to run from within.
```bash
rake docker
```

In the container check out the options:
```bash
run_tests/run_tests.sh -h
```

Example: Run the framework tests with ruby 2.5.3
```bash
run_tests/run_tests.sh -r 2.5.3 -g gemfiles/frameworks.gemfile
```

### Run one test from suite, a specific test file, or a specific test
While coding and for debugging it may be helpful to run fewer tests.
There are 2 options, either use the `run_tests` command or setup the
env and use `ruby -I test`

One test from suite:
```bash
run_tests/run_tests.sh -r 2.5.3 -g gemfiles/frameworks.gemfile -n 1
```

One file:
```bash
rbenv global 2.4.5
export BUNDLE_GEMFILE=gemfiles/delayed_job.gemfile
export DBTYPE=mysql2       # optional, defaults to postgresql
bundle
bundle exec ruby -I test queues/delayed_job-client_test.rb
```

A specific test:
```bash
rbenv global 2.5.3
export BUNDLE_GEMFILE=gemfiles/libraries.gemfile
export DBTYPE=mysql2
bundle
bundle exec ruby -I test instrumentation/moped_test.rb -n /drop_collection/
```

## byebug for debugging

The gem is setup to be debugged with `byebug`, add the following lines in the code for a break:
```ruby
require 'byebug'
byebug
```
See here for docu: https://github.com/deivid-rodriguez/byebug

## Duplication (◔_◔) and missing tests ( •̆௰•̆ )
Sorry, it takes some time to run all the tests (31 test suites, approx. 40
minutes in local docker container or travis with 5 workers). There is
duplication as well as omissions. The test code is a bit of a jungle, so
for now the aim is to get good coverage for added and refactored code and
clean up tests whenever it makes sense.

If you are contributing, please make sure all the tests pass and add
tests for your code, so that it can't be broken.

For questions with testing please contact the main contributor.
