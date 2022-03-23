# Debug the c-code with gdb

inspired by: https://dev.to/wataash/how-to-create-and-debug-ruby-gem-with-c-native-extension-3l8b


## install ruby with sources

rbenv is your friend ;) -k means keep sources

```
rbenv install -k 2.7.5
rbenv shell 2.7.5

# check that ruby is debuggable
type ruby           # => ruby is /home/wsh/.rbenv/shims/ruby
rbenv which ruby    # => /home/wsh/.rbenv/versions/2.6.3/bin/ruby
```


##
## add debug info when compiling solarwinds_apm
add this line to extconf.rb to turn off optimization

```
CONFIG["optflags"] = "-O0"
```


##
## start ruby app with gdb

This will run ruby and load the app with a breakpoint in the Reporter::startThread
c-function.

`bundle exec gdb -q -ex 'set breakpoint pending on' -ex 'b Reporter::startThread' -ex run --args ruby -e 'require "./app"'`

If there is a bug in the ruby code or a ruby byebug binding that halts the 
script, the debugger will hang without showing any output. 
So, make sure `bundle exec ruby app.rb` runs.

use the gdb navigation commands to step through the code. If it says:

```
(gdb) n
Single stepping until exit from function _ZN8Reporter11startThreadEv@plt,
which has no line number information.
```

type `c` and it may end up stopping in the right location.

##
## make ruby .gdbinit macros available

These macros are pretty elaborate. They are checked in the ruby github 
repo: https://github.com/ruby/ruby/blob/master/.gdbinit
The code is nicely formatted and colorized in github and easiest to read there.

installation in the user's home dir:
```
wget https://github.com/ruby/ruby/blob/master/.gdbinit
```
##
## examples

Some inspiring examples here:

https://jvns.ca/blog/2016/06/12/a-weird-system-call-process-vm-readv/

https://medium.com/@zanker/finding-a-ruby-bug-with-gdb-56d6b321bc86
