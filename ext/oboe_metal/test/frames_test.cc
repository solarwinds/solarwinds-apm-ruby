

#include <string.h>

#include <algorithm>

#include "../src/profiling.h"
#include "../src/frames.h"
#include "gtest/gtest.h"
#include "gmock/gmock.h"
#include "ruby/debug.h"
#include "ruby/ruby.h"
#include "test.h"

extern unordered_map<VALUE, FrameData> cached_frames;
extern int profiling_shutdown;

static VALUE test_frames[BUF_SIZE];
static int test_lines[BUF_SIZE];
int test_num;

static int ruby_version;

VALUE RubyCallsFrames::c_get_frames() {
    test_num = rb_profile_frames(1, sizeof(test_frames) / sizeof(VALUE), test_frames, test_lines);
    return Qnil;
}

void Init_RubyCallsFrames() {
    static VALUE cTest = rb_define_module("RubyCalls");
    rb_define_singleton_method(cTest, "get_frames", reinterpret_cast<VALUE (*)(...)>(RubyCallsFrames::c_get_frames), 0);

    VALUE result;
    result = rb_eval_string("RUBY_VERSION[0].to_i");
    ruby_version = NUM2INT(result);
};

TEST(Frames, reserve_cached_frames) {
    // it should only reserve once used during init
    // unordered_map grows automatically
    cached_frames.clear();

    Frames::reserve_cached_frames();
    int bucket_count = cached_frames.bucket_count();

    Frames::reserve_cached_frames();
    EXPECT_EQ(bucket_count, cached_frames.bucket_count());
}

TEST(Frames, collect_frame_data) {
    rb_eval_string("TestMe::Snapshot::all_kinds");

    int num = Frames::remove_garbage(test_frames, test_num);

    vector<FrameData> data;
    // Ruby 3 reports a <cfunc>, before the "take_snapshot" method
    // we have to adjust the index of the trace we are checking
    int i = ruby_version == 2 ? 0 : 1;
    Frames::collect_frame_data(test_frames, i + 1, data);

    EXPECT_EQ("take_snapshot", data[i].method) << "method name incorrect";
    EXPECT_EQ("TestMe::Snapshot", data[i].klass) << "klass name incorrect";
    std::size_t found = data[i].file.find("ext/oboe_metal/test/ruby_test_helper.rb");
    EXPECT_EQ(data[i].file.length() - 39, found)
        << "filename incorrect " << found << " " << data[i].file.length();
    EXPECT_EQ(7, data[i].lineno) << "line number incorrect";
}

TEST(Frames, remove_garbage) {
    // run some Ruby code and get a snapshot
    rb_eval_string("TestMe::Snapshot::all_kinds");

    int num = Frames::remove_garbage(test_frames, test_num);

    int expected = (ruby_version == 2) ? 7 : 9;
    EXPECT_EQ(expected, num)
        << "wrong number of expected frames after remove_garbage";
    // check no lineno 0 frame at top
    VALUE val;
    int i = (ruby_version == 2) ? 0 : 1;
    val = rb_profile_frame_first_lineno(test_frames[i]);  // returns line number
    if (RB_TYPE_P(val, T_FIXNUM)) {
        EXPECT_NE(0, NUM2INT(val))
            << "the frame with linenumber 0 was not removed";
    } else {
        EXPECT_TRUE(false) << " ************ line number not an int **********";
    }
    // check no repeated frames
    for (i = 0; i < num; i++)
        for (int j = i + 1; j < num; j++)
            EXPECT_NE(test_frames[i], test_frames[j])
                << "not all repeated frames were removed";
}

TEST(Frames, num_matching) {
    VALUE a[BUF_SIZE];
    VALUE b[BUF_SIZE];

    int a_num = 0;
    int b_num = 0;
    EXPECT_EQ(0, Frames::num_matching(a, a_num, b, b_num))
        << "* empty frames array should have 0 matches";

    a[0] = (VALUE)11;
    a[1] = (VALUE)12;
    a[2] = (VALUE)13;
    b[0] = (VALUE)11;
    b[1] = (VALUE)12;
    b[2] = (VALUE)13;
    a_num = 3;
    b_num = 3;
    EXPECT_EQ(3, Frames::num_matching(a, a_num, b, b_num))
        << "* equal frames array should have matched";

    b[1] = (VALUE)222;
    EXPECT_EQ(1, Frames::num_matching(a, a_num, b, b_num))
        << "* only one should match for same length but different content";

    b[1] = (VALUE)12;
    a[3] = 14;
    a_num = 4;
    EXPECT_EQ(0, Frames::num_matching(a, a_num, b, b_num))
        << "* different length, frames NOT matching from the end";

    a[0] = 10;
    a[1] = 11;
    a[2] = 12;
    a[3] = 13;
    EXPECT_EQ(3, Frames::num_matching(a, a_num, b, b_num))
        << "* different length, frames matching from the end";

    b[0] = (VALUE)18;
    b[1] = (VALUE)19;
    b[2] = (VALUE)11;
    b[3] = (VALUE)12;
    b[4] = (VALUE)13;
    b_num = 5;

    EXPECT_EQ(3, Frames::num_matching(a, a_num, b, b_num))
        << "* different length, frames matching from the end";
}

TEST(Frames, cached_frames) {
    cached_frames.clear();
    // run some Ruby code and get a snapshot
    rb_eval_string("TestMe::Snapshot::all_kinds");

    Frames::remove_garbage(test_frames, test_num);

    // Check the expected size
    int expected = (ruby_version == 2) ? 8 : 10;
    EXPECT_EQ(expected, cached_frames.size());

    // check that each frame is cached
    for (int i = 0; i < test_num; i++)
        EXPECT_EQ(1, cached_frames.count(test_frames[i]));

    // repeat
    rb_eval_string("TestMe::Snapshot::all_kinds");
    Frames::remove_garbage(test_frames, test_num);

    expected = (ruby_version == 2) ? 9 : 11;
    EXPECT_EQ(expected, cached_frames.size());  // +1 for an extra main frame
    for (int i = 0; i < test_num; i++)
        EXPECT_EQ(1, cached_frames.count(test_frames[i]));
}
