
#include "../src/frames.h"

#include <string.h>

#include <algorithm>

#include "../src/profiling.h"
#include "gtest/gtest.h"
#include "gmock/gmock.h"
#include "ruby/debug.h"
#include "ruby/ruby.h"
#include "test.h"

extern atomic_bool profiling_shutdown;

// FIXME how can I access profiling_shutdown ?
//TEST(Profiling, testing_something) {
//     int result;
//     result = Profiling::try_catch_shutdown([] {
//         // provoke exception
//         std::string ().replace (100, 1, 1, 'c');
//         return 0;
//     }, "Profiling::try_catch()");
//
//     EXPECT_NE(0, result);
//     EXPECT_EQ(true, profiling_shutdown);
//
//     // reset global var
//     profiling_shutdown = false;
//}
