// Copyright (c) 2019 SolarWinds, LLC.
// All rights reserved.

#include <iostream>

#ifdef __cplusplus
extern "C" {
#endif

void Init_oboe_metal(void);

void Init_profiling(void);

void Init_libsolarwinds_apm() {
    Init_oboe_metal();
    // Init_profiling();
}

#ifdef __cplusplus
}
#endif
