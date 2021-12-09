#smoketest

Quickly smoke test the solarwinds_apm gem uploaded to package cloud. There should be:

- a reporter init message indicating a working connection
- 5 traces in https://my-stg.appoptics.com/
- a WARN message with a trace-id

### how to...

The gem version needs to be updated in the Gemfile.

Use linux containers from parent directory

Inside a container run:  `./smoketest.sh` 

```
mkdir /smoke
cp -r test/run_tests/smoke_test/* /smoke/.
cd /smoke
rm -f Gemfile.lock
./smoketest.sh
cd -
/bin/rm -r /smoke
```
