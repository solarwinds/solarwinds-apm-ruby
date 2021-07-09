#include "gtest/gtest.h"
// #include "gmock/gmock.h"
#include <ruby/ruby.h>
#include "../src/profiling.h"
#include "../src/frames.h"
#include "test.h"

#ifndef FRAMES_BUFFER
#define FRAMES_BUFFER

using namespace std;

int main(int argc, char **argv) {
    int state = -1;

    // order important! init ruby before adding functions!
    ruby_init();
    Init_RubyCallsFrames();

    // !!! if the require path is wrong, cmake will segfault !!!
    string path(std::getenv("TEST_DIR"));
    string cmd("require '" + path + "/" + "ruby_test_helper.rb" + "'");
    rb_eval_string(cmd.c_str());

    ::testing::InitGoogleTest(&argc, argv);

    state = RUN_ALL_TESTS();

    ruby_cleanup(0);
    return state;
}
#endif //FRAMES_BUFFER