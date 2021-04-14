#include "gtest/gtest.h"
// #include "gmock/gmock.h"
#include <ruby/ruby.h> // TODO - how does it find this
#include "../src/frames.h"
#include "test.h"

#ifndef FRAMES_BUFFER
#define FRAMES_BUFFER

int main(int argc, char **argv) {
    // order important! init ruby before adding functions!
    ruby_init();
    Init_RubyCallsFrames();
    rb_eval_string("require_relative './ruby_test_helper.rb'");

    ::testing::InitGoogleTest(&argc, argv);

    int state = RUN_ALL_TESTS();

    ruby_cleanup(0);

    return state;
}
#endif //FRAMES_BUFFER
