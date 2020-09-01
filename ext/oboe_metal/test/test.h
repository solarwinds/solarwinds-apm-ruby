#ifndef TEST_H
#define TEST_H

class RubyCallsFrames {
    public:
    static VALUE c_get_frames();
};

void Init_RubyCallsFrames();

#endif //TEST_H