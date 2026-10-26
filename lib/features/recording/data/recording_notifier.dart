import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/recording_notification.dart';

/// 기록 중 상단 고정 알림의 내용을 바꾼다. 테스트에서는 가짜로 바꿔 끼운다.
abstract interface class RecordingNotifier {
  /// 알림 내용을 [content]로 바꾼다.
  Future<void> show(RecordingNotificationContent content);

  /// 알림을 지운다. (일시정지·종료)
  Future<void> cancel();
}

/// 위치 패키지(geolocator)가 기록 유지용으로 띄운 알림을 **같은 번호로 다시 올려** 내용을 덮어쓴다.
/// 그래서 알림은 하나만 보이고, 기록 유지(포그라운드 서비스)는 그대로 위치 패키지가 맡는다.
///
/// 주의: 아래 번호와 채널은 geolocator_android 내부 값이다
/// (GeolocatorLocationService.ONGOING_NOTIFICATION_ID, CHANNEL_ID).
/// 위치 패키지를 업데이트하면 GeolocatorLocationService.java에서 값이 그대로인지 확인한다.
class LocalRecordingNotifier implements RecordingNotifier {
  static const notificationId = 75415;
  static const channelId = 'geolocator_channel_01';

  /// location_service.dart의 ForegroundNotificationConfig.notificationChannelName과 같게 둔다.
  static const channelName = '등산 기록';

  final _plugin = FlutterLocalNotificationsPlugin();
  Future<bool?>? _init;

  Future<void> _ready() => _init ??= _plugin.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ),
  );

  @override
  Future<void> show(RecordingNotificationContent content) async {
    try {
      await _ready();
      await _plugin.show(
        id: notificationId,
        title: content.title,
        body: content.body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            channelName,
            importance: Importance.low,
            priority: Priority.low,
            // 밀어서 지울 수 없고, 바뀔 때마다 소리·진동을 내지 않는다.
            ongoing: true,
            autoCancel: false,
            onlyAlertOnce: true,
            silent: true,
            // 시간은 알림이 스스로 1초마다 올린다.
            showWhen: true,
            usesChronometer: true,
            when: content.chronometerBase.millisecondsSinceEpoch,
            visibility: NotificationVisibility.public,
            category: AndroidNotificationCategory.progress,
          ),
        ),
      );
    } catch (e) {
      // 알림을 못 바꿔도 기록은 계속된다.
      debugPrint('[notification] 알림을 바꾸지 못했어요: $e');
    }
  }

  @override
  Future<void> cancel() async {
    try {
      await _ready();
      await _plugin.cancel(id: notificationId);
    } catch (e) {
      debugPrint('[notification] 알림을 지우지 못했어요: $e');
    }
  }
}

final recordingNotifierProvider = Provider<RecordingNotifier>(
  (ref) => LocalRecordingNotifier(),
);
