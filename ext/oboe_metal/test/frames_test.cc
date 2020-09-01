
#include <algorithm>
#include <string.h>

#include "ruby/ruby.h"

#include "test.h"
#include "../src/frames.h"

#include "gtest/gtest.h"
// #include "gmock/gmock.h"

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
};

TEST (Frames, extract_frame_info) {
    rb_eval_string("TestMe::Snapshot::all_kinds");
    FrameData info;
    Frames::extract_frame_info(test_frames[0], &info);

    EXPECT_EQ("take_snapshot", info.method)
        << "method name incorrect";
    EXPECT_EQ("TestMe::Snapshot", info.klass)
        << "klass name incorrect";
    std::size_t found = info.file.find("ext/oboe_metal/test/ruby_test_helper.rb");
    EXPECT_EQ(info.file.length() - 39, found)
        << "filename incorrect " << found << " " << info.file.length();
    EXPECT_EQ(7, info.lineno)
        << "line number incorrect";
}

TEST(Frames, remove_garbage){
    // run some Ruby code and get a snapshot
    rb_eval_string("TestMe::Snapshot::all_kinds");

    // for(int i = 0; i < test_num; i++)
    //     Frames::print_raw_frame_info(test_frames[i]);
    // cout << endl;

    int num = Frames::remove_garbage(test_frames, test_num);
    // for(int i = 0; i < num; i++)
    //     Frames::print_raw_frame_info(test_frames[i]);

    EXPECT_EQ(7, num)
        << "wrong number of expected frames after remove_garbage";
    // check no lineno 0 frame at top
    EXPECT_NE(0, NUM2INT(rb_profile_frame_first_lineno(test_frames[0])))
        << "the frame with linenumbber 0 was not removed";
    // check no repeted frames
    int i = 0;
    for (i = 0; i < num; i++)
        for (int j = i + 1; j < num; j++)
            if (test_frames[i] == test_frames[j]) break;
    EXPECT_EQ(num, i)
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
