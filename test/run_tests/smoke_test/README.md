#smoketest

Quickly test the current gem uploaded to package cloud.
If it is not uploaded, this fails as it matches the info in version.rb

use linux containers from parent directory

inside container

run script `./smoketest.sh` locally

or call it from any directory: `bundle exec rake smoke`

- it uses the latest gem version from packagecloud
- it sends traces to the collector
