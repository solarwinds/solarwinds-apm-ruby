#include <iostream>

#ifdef __cplusplus
extern "C"
#endif
void Init_oboe_metal(void);

#ifdef __cplusplus
extern "C"
#endif
void Init_profiling(void);

#ifdef __cplusplus
extern "C"
#endif
void Init_rb_appoptics_apm() {
    Init_oboe_metal();
    std::cout << "*** oboe_metal initialized ***" << std::endl;
    Init_profiling();
    std::cout << "*** profiling intitialized ***" << std::endl;
}
