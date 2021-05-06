cmake_minimum_required(VERSION 3.1)

 # specify the C++ standard
set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED True)
set(CMAKE_MODULE_PATH ${CMAKE_CURRENT_LIST_DIR} ${CMAKE_MODULE_PATH} ${CMAKE_CURRENT_LIST_DIR}/FindGMock.cmake)
message(STATUS "${CMAKE_MODULE_PATH}")

# Locate GTest
find_package(GTest REQUIRED)

# Locate GMock
find_package(GMock REQUIRED)

include_directories(
  ${GTEST_INCLUDE_DIRS}
  ../src/
  $ENV{RUBY_INC_DIR}
  $ENV{RUBY_INC_DIR}/x86_64-linux/
)

link_directories(
  /usr/lib/
  $ENV{RUBY_PREFIX}/lib/
  ../../../lib/
  ../lib
)

set (sources
  test_main.cc
  frames_test.cc
  profiling_test.cc
)

# Link runTests with what we want to test and the GTest and pthread library
add_executable(runTests ${sources})
target_link_libraries(runTests
  ${GTEST_LIBRARIES}
  appoptics_apm.so
  liboboe.so
  libruby.so
  pthread
)


target_include_directories( runTests PUBLIC ../src/ )
