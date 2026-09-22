// Replaces mediapipe::tasks::core::logging::CreateTasksLogger from the
// official iOS pod, whose graph library builds a Clearcut telemetry client
// (Ion HTTP over GTMSessionFetcher) for every task. Returning the no-op
// logger, as the open-source factory does, leaves that client unreferenced so
// the objects in config/excluded-graph-objects.txt can be dropped.
//
// The pod ships no C++ headers, so the interface is restated here; it must
// match mediapipe/tasks/cc/core/logging/tasks_logger.h of the pinned
// MediaPipe version (mangled names and vtable order).
#include <cstdint>
#include <memory>

namespace mediapipe {

class Timestamp {
  [[maybe_unused]] int64_t timestamp_;
};

namespace tasks::core::logging {

struct LoggingOptions;

class TasksLogger {
 public:
  struct StatsSnapshot;

  virtual ~TasksLogger() = default;
  virtual void LogSessionStart() = 0;
  virtual void LogSessionClone() = 0;
  virtual void RecordCpuInputArrival(Timestamp packet_timestamp) = 0;
  virtual void RecordGpuInputArrival(Timestamp packet_timestamp) = 0;
  virtual void RecordInvocationEnd(Timestamp packet_timestamp) = 0;
  virtual void LogInvocationReport(const StatsSnapshot& stats) = 0;
  virtual void LogSessionEnd() = 0;
  virtual void LogInitError() = 0;
};

class TasksDummyLogger : public TasksLogger {
 public:
  void LogSessionStart() override {}
  void LogSessionClone() override {}
  void RecordCpuInputArrival(Timestamp) override {}
  void RecordGpuInputArrival(Timestamp) override {}
  void RecordInvocationEnd(Timestamp) override {}
  void LogInvocationReport(const StatsSnapshot&) override {}
  void LogSessionEnd() override {}
  void LogInitError() override {}
};

std::unique_ptr<TasksLogger> CreateTasksLogger(const LoggingOptions&) {
  return std::make_unique<TasksDummyLogger>();
}

}  // namespace tasks::core::logging
}  // namespace mediapipe
