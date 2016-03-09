# TraceView Gem Configuration

## Environment Variables

The following environment variables are detected by the traceview gem and affect how the gem functions.

### General

Name | Description | Default
---- | ----------- | -------
`IGNORE_TRACEVIEW_WARNING` | tells the traceview gem to __not__ output the _missing TraceView libraries_ message on stack initialization | `false`
`TRACEVIEW_GEM_VERBOSE` | sets the verbose flag (`TraceView::Config[:verbose]`) early in the gem loading process which may output valuable information | `false`
`TRACEVIEW_CUUID` | Allows specifying the customer ID via environment variable to override/bypass the value in `/etc/tracelytics.conf` | `nil`

# Related to Tests

Name | Description | Default
---- | ----------- | -------
`TRACEVIEW_GEM_TEST` | puts the gem in test mode.  Traces are written to /tmp/trace_output.bson. | `false`
`DBTYPE` | For tests on Ruby on Rails, specifies the database type to test against.  `postgres`, `mysql` and `mysql2` are valid options. | `postgres`
`TV_CASSANDRA_SERVER` | specifies the Cassandra server to test against. | `127.0.0.1:9160`
`TV_MONGO_SERVER` | specifies the Mongo server to test against. | `127.0.0.1:27017`
`TV_RABBITMQ_SERVER` | specifies the RabbitMQ server to test against. | `127.0.0.1`
`TV_RABBITMQ_PORT` | port for the RabbitMQ connection. | `5672`
`TV_RABBITMQ_USERNAME` | username for the RabbitMQ connection | `guest`
`TV_RABBITMQ_PASSWORD` | password for the RabbitMQ connection | `guest`

## TraceView::Config

`TraceView::Config` is a nested hash used by the traceview gem to store preferences and switches.

See [this Rails generator template file](https://github.com/appneta/oboe-ruby/blob/master/lib/rails/generators/traceview/templates/traceview_initializer.rb) for documentation on all of the supported values.

