// Copyright (c) 2020 SolarWinds, LLC.
// All rights reserved.

#include "frames_v2.h"
#include <algorithm>
#include <regex>

int Frames::find_new_frames(const vector<string> frames,
                            const vector<string> prev_frames,
                            vector<string> &new_frames,
                            int &num_exited) {
    // static int count = 0;
    int i = 0;

    vector<string> frames_reverse = frames;
    reverse(begin(frames_reverse), end(frames_reverse));
    vector<string> prev_frames_reverse = prev_frames;
    reverse(begin(prev_frames_reverse), end(prev_frames_reverse));

    // if (count > 1 && count < 4) {
    //     cout << endl
    //          << "current stack: " << endl;
    //     for (auto frame : frames_reverse) {
    //         cout << i << " " << frame << endl;
    //         i++;
    //     }
    //     cout << endl
    //          << "previous stack: " << endl;
    //     i = 0;
    //     for (auto frame : prev_frames_reverse) {
    //         cout << i << " " << frame << endl;
    //         i++;
    //     }
    //     cout << endl
    //          << endl;
    // }

    int min_length = min(frames.size(), prev_frames.size());

    for (i = 0; i < min_length; i++) {
        if (frames_reverse[i] != prev_frames_reverse[i])
            break;
    }

    num_exited = prev_frames.size() - i;
    int num_new = frames.size() - i;

    new_frames.assign(frames.begin(), frames.begin() + num_new);

    // if (count < 4) {
    //     i = 0;
    //     cout << endl
    //          << "total frames: " << frames.size()
    //          << ", num_exited: " << num_exited << ", new frames: " << endl;
    //     for (auto frame : new_frames) {
    //         cout << i << " " << frame << endl;
    //         i++;
    //     }
    // }
    // count++;

    return 1;
}

int Frames::extract_frame_info(vector<string> frames, vector<FrameData> &frame_data) {
    FrameData tmp;
    regex pattern("^([^:]*):(\\d*)[^`]*`([^']*)'");
    smatch m;

    for (auto frame : frames) {
        // find file, lineno, method in frame string
        // and assign to frame_data
        regex_match(frame, m, pattern);
        tmp.file = m[1];

        try {
            tmp.lineno = stoi(m[2]);
        } catch(invalid_argument) {
            // do nothing
            OBOE_DEBUG_LOG_ERROR(OBOE_MODULE_LIBOBOE, "AO_PROFILING: No valid line number received");
        }

        tmp.method = m[3];
        // it seems to include the call to backtrace,
        // which we don't need to show in the profile
        if (tmp.method != "backtrace")
            frame_data.push_back(tmp);
    }

    return 1;
}
