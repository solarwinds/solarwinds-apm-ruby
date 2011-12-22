require 'mkmf'

if `uname -a`.match(/Darwin/)
    $stderr.puts "Warning: native extension disabled on OS X. This will not work."
    `printf "all:\n\ninstall:\n\nclean:\n\n" > Makefile`
else
    $libs = append_library($libs, "oboe")
    $libs = append_library($libs, "stdc++")

    $CFLAGS << " #{ENV["CFLAGS"]}"
    $CPPFLAGS << " #{ENV["CPPFLAGS"]}"
    $LIBS << " #{ENV["LIBS"]}"

    cpp_command('g++') if RUBY_VERSION < '1.9'
    create_makefile('oboe_ext')
end
