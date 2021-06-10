
#include "../src/frames.h"

#include <string.h>

#include <algorithm>
#include <thread>
#include <array>

#include "../src/profiling.h"
#include "gtest/gtest.h"
#include "gmock/gmock.h"
#include "ruby/debug.h"
#include "ruby/ruby.h"
#include "test.h"

extern atomic_bool profiling_shut_down;
// extern oboe_reporter_t *cur_reporter;

// FIXME how can I access profiling_shut_down ?
TEST(Profiling, try_catch_shutdown) {
    EXPECT_FALSE(profiling_shut_down);

    int result;
    result = Profiling::try_catch_shutdown([] {
        // provoke exception
        std::string ().replace (100, 1, 1, 'c');
        return 0;
    }, "Profiling::try_catch()");

    EXPECT_NE(0, result);
    EXPECT_TRUE(profiling_shut_down); 

    // reset global var
    profiling_shut_down = false;
}

TEST(Profiling, oboe_0_profiling) {
    atomic_bool atomic_a1{true};
    atomic_bool atomic_a2{false};

    atomic_bool running;

    cout << running << endl;
    cout << running.exchange(true) << endl;
    cout << running.exchange(true) << endl;

    // cout << "prev val " << atomic_a2.exchange(false) << endl;
    // cout << atomic_a2 << endl;
    // cout << "prev val " <<  atomic_a2.exchange(true) << endl;
    // cout << atomic_a2 << endl;
    // cout << "prev val " <<  atomic_a2.exchange(true) << endl;
    // cout << atomic_a2 << endl;
    // cout << "prev val " <<  atomic_a2.exchange(false) << endl;
    // cout << atomic_a2 << endl;



    // static bool b1{true};
    // static bool b2{false};

    // array<thread, 4> threads;

    // for (auto& t : threads) {
    //     t = thread([] { Profiling::profiler_signal_handler(0, NULL, NULL); });
    // }

    // cout << "waiting..." << endl;

    // for (auto& t : threads) {
    //     t.join();
    // }

    // cout << "Done." << endl;


    // cout << atomic_a1 << ", " << b1 << endl;
    // cout << atomic_a1 << ", " << b1 << ", " << atomic_a1.compare_exchange_weak(b1, false) << endl;
    // cout << atomic_a1 << ", " << b1 << endl;
    // cout << atomic_a2 << ", " << b2 << endl;
    // cout << atomic_a2 << ", " << b2 << ", " << atomic_a2.compare_exchange_weak(b2, true) << endl;
    // cout << atomic_a2 << ", " << b2 << endl;
    // cout << endl;

    // cout << atomic_a1 << ", " << b1 << endl;
    // cout << atomic_a1 << ", " << b1 << ", " << atomic_a1.compare_exchange_weak(b1, false) << endl;
    // cout << atomic_a1 << ", " << b1 << endl;
    // cout << atomic_a2 << ", " << b2 << endl;
    // cout << atomic_a2 << ", " << b2 << ", " << atomic_a2.compare_exchange_weak(b2, true) << endl;
    // cout << atomic_a2 << ", " << b2 << endl;
    // cout << endl;
    
     
}
