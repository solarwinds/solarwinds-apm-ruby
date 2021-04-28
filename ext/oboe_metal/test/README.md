C-code tests:

Make sure gtests are installed and compiled
`apt update && apt install libgtest-dev google-mock cmake`
`cd /usr/src/gtest`
as root or use sudo:
`cmake .`
`make`
`mv libg* /usr/lib/`

run c++ tests in the ext/oboe_metal/test directory:

`cmake CMakeLists.txt`

if there is a warning `Could NOT find PkgConfig (missing:  PKG_CONFIG_EXECUTABLE)`
either ignore it or install `pkg-config`

`make`

`./runTests`

If it can't find the ruby headers, then maybe the ruby version set in CMakeTLists.txt is
not installed. Either change the version or install it. 

These tests complement the tests run in Ruby, e.g.:

Logging is tested in Ruby as integration tests that verify the different 
KVs and values in the resulting traces.
Those tests use the same approach as is used for traces without profiling.


To ony run specific tests use --gtest_filter, e.g:
`./runTests --gtest_filter=*cached*`
