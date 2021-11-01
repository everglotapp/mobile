import 'package:everglot/jobs/sync_fcm_token.dart';
import 'package:everglot/jobs/types.dart';
import 'package:workmanager/workmanager.dart';

void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    final jobType = findJobType(task);
    switch (jobType) {
      case JobType.syncFcmToken:
        return await syncFcmToken(inputData);
      case JobType.iOSBackgroundTask:
        return await syncFcmToken(inputData);
      case null:
        return Future.value(true);
    }
  });
}
