# SolarWindsAPM Gem Configuration

## Environment Variables

The following environment variables are detected by the solarwinds_apm gem and affect how the gem functions.

### General

Name | Description | Default
---- | ----------- | -------
`SW_AMP_SERVICE_KEY` | API token + service name combination, mandatory for metrics and traces to show in my.appoptics.com |
`SW_AMP_NO_LIBRARIES_WARNING` | tells the solarwinds_apm gem to __not__ output the _missing SolarWindsAPM libraries_ message on stack initialization | `false`
`SW_AMP_GEM_VERBOSE` | sets the verbose flag (`SolarWindsAPM::Config[:verbose]`) early in the gem loading process which may output valuable information | `false`

# Related to Tests

Name | Description | Default
---- | ----------- | -------
`SW_AMP_GEM_TEST` | puts the gem in test mode to avoid restarting certain background services used in testing.   `false`
`DBTYPE` | For tests on Ruby on Rails, specifies the database type to test against.  `postgres`, `mysql` and `mysql2` are valid options. | `postgres`
`SW_AMP_CASSANDRA_SERVER` | specifies the Cassandra server to test against. | `127.0.0.1:9160`
`MONGO_SERVER` | specifies the Mongo server to test against. | `127.0.0.1:27017`
`RABBITMQ_SERVER` | specifies the RabbitMQ server to test against. | `127.0.0.1`
`RABBITMQ_PORT` | port for the RabbitMQ connection. | `5672`
`RABBITMQ_USERNAME` | username for the RabbitMQ connection | `guest`
`RABBITMQ_PASSWORD` | password for the RabbitMQ connection | `guest`

## SolarWindsAPM::Config

`SolarWindsAPM::Config` is a nested hash used by the solarwinds_apm gem to store preferences and switches.

See [this Rails generator template file](https://github.com/librato/ruby-appoptics/blob/master/lib/rails/generators/appoptics_apm/templates/appoptics_initializer.rb) for documentation on all of the supported values.
