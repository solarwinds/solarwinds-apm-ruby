cmake_minimum_required(VERSION 3.13)
project(test)

 # specify the C++ standard
set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED True)
# set(CMAKE_MODULE_PATH ${CMAKE_CURRENT_LIST_DIR} ${CMAKE_MODULE_PATH} ${CMAKE_CURRENT_LIST_DIR}/FindGMock.cmake)

include(FetchContent)
FetchContent_Declare(
  googletest
  URL https://github.com/google/googletest/archive/609281088cfefc76f9d0ce82e1ff6c30cc3591e5.zip
#  URL https://github.com/google/googletest/archive/refs/tags/release-1.11.0.zip
)

# For Windows: Prevent overriding the parent project's compiler/linker settings
set(gtest_force_shared_crt ON CACHE BOOL "" FORCE)
FetchContent_MakeAvailable(googletest)

include_directories(
  ${gtest_SOURCE_DIR}/include
  ../src/
  $ENV{RUBY_INC_DIR}
  $ENV{RUBY_INC_DIR}/x86_64-linux/
)

link_directories(
#  /usr/lib/
  $ENV{RUBY_PREFIX}/lib/
  ../../../lib/
  ../lib
)

enable_testing()
set (sources
  test_main.cc
  frames_test.cc
  profiling_test.cc
)

## Link runTests with what we want to test and the GTest and pthread library
add_executable(runTests ${sources})
target_link_libraries(runTests
#  ${GTEST_LIBRARIES}
  gtest
  appoptics_apm.so
  liboboe.so
  libruby.so
  pthread
)

include(GoogleTest)
gtest_discover_tests(runTests)
