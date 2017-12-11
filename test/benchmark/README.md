#Micro Benchmarking

Work In Progress

In this folder there are samples for doing microbenchmarks. 

They are in folders with names indicating which gemfile needs to be set, eg:
```
export BUNDLE_GEMFILE=gemfiles/libraries.gemfile
bundle install
```

The gems used are `benchmark-ips` and `benchmark-memory` to compare performance and memory usage between different 
versions of code.

The variable `ENV['TEST_AB']` is used to define which version of code to run.

**!!! It is very important to remove `ENV['TEST_AB']` before commiting code !!!**

###Example of setup for benchmarking:

The benchmarking code to be run:
```
Benchmark.ips do |x|
  x.config(:time => 20, :warmup => 20, :iterations => 3)
  @conn = Bunny.new(@connection_params)
  @conn.start
  @channel = @conn.create_channel
  @queue = @channel.queue("ao.ruby.test")
  @exchange = @channel.topic("ao.ruby.topic.tests", :auto_delete => true)
  
  x.report('bunny_pub_sampling_A') do
    ENV['TEST_AB'] = 'A'
    AppOptics.loaded = true
    AppOptics::Config[:tracing_mode] = 'always'
    AppOptics::Context.fromString('2B7435A9FE510AE4533414D425DADF4E180D2B4E3649E60702469DB05F00')

    dostuff(@exchange)
  end
  
  x.report('bunny_pub_sampling_B') do
    ENV['TEST_AB'] = 'B'
    AppOptics.loaded = true
    AppOptics::Config[:tracing_mode] = 'always'
    AppOptics::Context.fromString('2B7435A9FE510AE4533414D425DADF4E180D2B4E3649E60702469DB05F00')

    dostuff(@exchange)
  end
  
  x.compare!
end
```
The code to be benchmarked:
```
 def basic_publish_with_appoptics(payload, exchange, routing_key, opts = {})
    # If we're not tracing, just do a fast return.
    return basic_publish_without_appoptics(payload, exchange, routing_key, opts) if !AppOptics.tracing? && ENV['TEST_AB'] == 'B'

    begin
       kvs = collect_channel_kvs
       if exchange.respond_to?(:name)
          kvs[:ExchangeName] = exchange.name
       elsif exchange.respond_to?(:empty?) && !exchange.empty?
    ...
```
