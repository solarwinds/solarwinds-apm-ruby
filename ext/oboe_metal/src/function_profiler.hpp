// function_profiler C++11 per-thread function profling
// https://git.the-pluc.net/function_profiler.git/
// Version 0.3
//
// Copyright (C) 2015, 2016 Pierre-Luc Perrier <pluc@the-pluc.net>
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#ifndef function_profiler_h
#define function_profiler_h

#ifdef FP_ENABLE

#include <boost/chrono.hpp>

#include <cstdio> // std::printf
#include <ios>    // std::hex
#include <string> // std::string
#include <thread> // std::this_thread::get_id
#include <iostream>
#include <iomanip>

namespace fp {

// Main structure used to collect data
struct collector {
  // Clocks
  using thread_clock = boost::chrono::thread_clock;
  using thread_time_point = thread_clock::time_point;
  using thread_accumulator = boost::chrono::duration<uint_least64_t, thread_clock::period>;

  using steady_clock = boost::chrono::steady_clock;
  using steady_time_point = steady_clock::time_point;
  using steady_accumulator = boost::chrono::duration<uint_least64_t, steady_clock::period>;

  // The duration we use for the report
  using report_duration = boost::chrono::duration<double, boost::milli>;

  collector() = delete;
  collector(const std::string &name)
    : m_thread_last{thread_clock::now()},
      m_steady_last{steady_clock::now()},
      m_count{0},
      m_thread_accumulator{0},
      m_steady_accumulator{0},
      m_last_report{steady_clock::now()}
  {
    std::ostringstream os;
    // os << "[FP] " << std::hex << std::this_thread::get_id() << " " << name << " #%-7lu %8.5F %8.5F %11.4F %11.4F\n";
    os << std::setfill (' ') << std::setw(22) << name << "  " << std::hex << std::this_thread::get_id() << "\t#%-7lu\t%4.5F\t%4.5F\t%6.4F\t%6.4F\n";
    m_fmt = os.str();
  }

  // We also report upon destruction. Note: this is probably a bad
  // idea.
  ~collector() noexcept
  {
    report();
  }

  inline void start() noexcept
  {
    m_thread_last = thread_clock::now();
    m_steady_last = steady_clock::now();
  }

  inline void stop()
  {
    ++m_count;

    {
      const auto now = thread_clock::now();
      m_thread_accumulator += now - m_thread_last;
      m_thread_last = std::move(now);
    }
    {
      const auto now = steady_clock::now();
      m_steady_accumulator += now - m_steady_last;
      m_steady_last = std::move(now);
    }

    // Check if we need to report current stats
    if (m_steady_last - m_last_report > report_interval) {
      m_last_report = m_steady_last;
      report();
    }
  }

private:
  inline void report() const
  {
    if (m_count == 0) return;
    const auto thread_ms = report_duration{m_thread_accumulator}.count();
    const auto steady_ms = report_duration{m_steady_accumulator}.count();
    std::printf(m_fmt.c_str(), m_count, steady_ms / m_count, thread_ms / m_count, steady_ms, thread_ms);
  }

private:
  static constexpr auto report_interval = boost::chrono::seconds{1};

  thread_time_point m_thread_last;         // Last thread clock time point
  steady_time_point m_steady_last;         // Last steady clock time point
  uint_least64_t m_count;                  // Number of samples
  thread_accumulator m_thread_accumulator; // Total thread clock duration
  steady_accumulator m_steady_accumulator; // Total steady clock duration
  steady_time_point m_last_report;         // Last report
  std::string m_fmt;                       // Format used for reporting
};

// RAII structure responsible to update a collector
struct scoped_profiler {
public:
  scoped_profiler(collector &collector_) : m_collector{collector_}
  {
    m_collector.start();
  }

  ~scoped_profiler()
  {
    m_collector.stop();
  }

  scoped_profiler() = delete;
  scoped_profiler(const scoped_profiler &) = delete;
  scoped_profiler(scoped_profiler &&) = delete;

  scoped_profiler &operator=(const scoped_profiler &) = delete;
  scoped_profiler &operator=(scoped_profiler &&) = delete;

private:
  collector &m_collector;
};

// constexpr boost::chrono::seconds collector::report_interval;

} // namespace fp

// Note: __func__ is not a preprocessor macro, it's a 'function-local
// predefined variable' (char *), hence we don't expand it.
#define PROFILE_FUNCTION()                                                                                             \
  thread_local fp::collector fp_info_fp{__func__};                                                                     \
  fp::scoped_profiler fp_scoped_profiler_fp{fp_info_fp};

#else // !FB_ENABLE

#define PROFILE_FUNCTION() static_cast<void>(0);

#endif // FB_ENABLE

#endif // function_profiler_h
