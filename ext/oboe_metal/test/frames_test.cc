
#include <algorithm>
#include <string.h>

#include "ruby/ruby.h"
#include "ruby/debug.h"

#include "test.h"
#include "../src/frames.h"
#include "../src/profiling.h"

#include "gtest/gtest.h"
// #include "gmock/gmock.h"

extern unordered_map<VALUE, FrameData> cached_frames;

static VALUE test_frames[BUF_SIZE];
static int test_lines[BUF_SIZE];
int test_num;

VALUE RubyCallsFrames::c_get_frames() {
    test_num = rb_profile_frames(1, sizeof(test_frames)/sizeof(VALUE), test_frames, test_lines);
    return Qnil;
}

void Init_RubyCallsFrames() {
    static VALUE cTest = rb_define_module("RubyCalls");
    rb_define_singleton_method(cTest, "get_frames", reinterpret_cast<VALUE (*)(...)>(RubyCallsFrames::c_get_frames), 0);
    cached_frames.reserve(1024);
};

TEST (Frames, collect_frame_data) {
    rb_eval_string("TestMe::Snapshot::all_kinds");

    int num = Frames::remove_garbage(test_frames, test_num);
    
    vector<FrameData> data;
    Frames::collect_frame_data(test_frames, 1, data);

    EXPECT_EQ("take_snapshot", data[0].method)
        << "method name incorrect";
    EXPECT_EQ("TestMe::Snapshot", data[0].klass)
        << "klass name incorrect";
    std::size_t found = data[0].file.find("ext/oboe_metal/test/ruby_test_helper.rb");
    EXPECT_EQ(data[0].file.length() - 39, found)
        << "filename incorrect " << found << " " << data[0].file.length();
    EXPECT_EQ(7, data[0].lineno)
        << "line number incorrect";
}

TEST(Frames, remove_garbage){
    // run some Ruby code and get a snapshot
    rb_eval_string("TestMe::Snapshot::all_kinds");

    int num = Frames::remove_garbage(test_frames, test_num);

    EXPECT_EQ(7, num)
        << "wrong number of expected frames after remove_garbage";
    // check no lineno 0 frame at top
    EXPECT_NE(0, NUM2INT(rb_profile_frame_first_lineno(test_frames[0])))
        << "the frame with linenumbber 0 was not removed";
    // check no repeted frames
    int i = 0;
    for (i = 0; i < num; i++)
        for (int j = i + 1; j < num; j++)
            EXPECT_NE(test_frames[i], test_frames[j])
                << "not all repeated frames were removed";
}

TEST(Frames, cached_frames) {
    cached_frames.clear();
    // run some Ruby code and get a snapshot
    rb_eval_string("TestMe::Snapshot::all_kinds");

    for(int i = 0; i <test_num; i++)
        Frames::print_raw_frame_info(test_frames[i]);

    Frames::remove_garbage(test_frames, test_num);

    // Check the expected size
    EXPECT_EQ(8, cached_frames.size());

    // check that each frame is cached
    for(int i = 0; i < test_num; i++)
        EXPECT_EQ(1, cached_frames.count(test_frames[i])); 

    // repeat
    rb_eval_string("TestMe::Snapshot::all_kinds");
    Frames::remove_garbage(test_frames, test_num);
    EXPECT_EQ(9, cached_frames.size()); // +1 for an extra main frame
    for (int i = 0; i < test_num; i++)
        EXPECT_EQ(1, cached_frames.count(test_frames[i])); 
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
