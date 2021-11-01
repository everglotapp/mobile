import 'package:workmanager/workmanager.dart';

enum JobType {
  syncFcmToken,
  iOSBackgroundTask,
}

const Map<JobType, String> jobTypes = {JobType.syncFcmToken: "syncFcmToken"};

JobType? findJobType(String type) {
  switch (type) {
    case "syncFcmToken":
      return JobType.syncFcmToken;
    case Workmanager.iOSBackgroundTask:
      return JobType.iOSBackgroundTask;
  }
}
