#include <iostream>

#ifdef __cplusplus
extern "C" {
#endif

void Init_oboe_metal(void);

void Init_profiling(void);

void Init_libappoptics_apm() {
    Init_oboe_metal();
//     std::cout << "*** oboe_metal initialized ***" << std::endl;
    Init_profiling();
//     std::cout << "*** profiling intitialized ***" << std::endl;
}

#ifdef __cplusplus
}
#endif
