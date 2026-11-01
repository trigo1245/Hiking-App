import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiking_app/app/app.dart';
import 'package:hiking_app/core/database/app_database.dart';
import 'package:hiking_app/core/map/map_tiles.dart';
import 'package:hiking_app/core/photos/photo_picker.dart';
import 'package:hiking_app/core/utils/clock.dart';
import 'package:hiking_app/features/achievements/data/achievement_remote.dart';
import 'package:hiking_app/features/activities/data/activity_photo_remote.dart';
import 'package:hiking_app/features/activities/data/activity_remote.dart';
import 'package:hiking_app/features/activities/data/gpx_sharer.dart';
import 'package:hiking_app/features/auth/data/auth_repository.dart';
import 'package:hiking_app/features/auth/data/avatar_remote.dart';
import 'package:hiking_app/features/auth/data/profile_remote.dart';
import 'package:hiking_app/features/auth/domain/profile.dart';
import 'package:hiking_app/features/auth/presentation/auth_providers.dart';
import 'package:hiking_app/features/auth/presentation/private_info_screen.dart';
import 'package:hiking_app/features/chat/data/chat_remote.dart';
import 'package:hiking_app/features/clubs/data/club_remote.dart';
import 'package:hiking_app/features/courses/data/competition_remote.dart';
import 'package:hiking_app/features/courses/data/course_remote.dart';
import 'package:hiking_app/features/courses/data/review_remote.dart';
import 'package:hiking_app/features/recording/data/location_service.dart';
import 'package:hiking_app/features/recording/data/recording_notifier.dart';
import 'package:hiking_app/features/shop/data/shop_remote.dart';
import 'package:hiking_app/features/subscription/data/subscription_remote.dart';

import '../features/achievements/fake_achievement_remote.dart';
import '../features/activities/fake_activity_remote.dart';
import '../features/auth/fake_profile_remote.dart';
import '../features/chat/fake_chat_remote.dart';
import '../features/clubs/fake_club_remote.dart';
import '../features/courses/fake_competition_remote.dart';
import '../features/courses/fake_course_remote.dart';
import '../features/fakes_phase2.dart';
import '../features/photo_fakes.dart';
import '../features/recording/fake_location_service.dart';
import '../features/shop/fake_shop_remote.dart';

/// 테스트용 메모리 DB. 테스트가 끝나면 닫힌다.
/// closeStreamsSynchronously: 목록 화면이 DB를 지켜보는 스트림을 타이머 없이 바로 닫는다.
/// (위젯 테스트는 끝날 때 남은 타이머가 있으면 실패로 본다)
AppDatabase testDatabase() {
  final db = AppDatabase(
    DatabaseConnection(
      NativeDatabase.memory(),
      closeStreamsSynchronously: true,
    ),
  );
  addTearDown(db.close);
  return db;
}

/// Supabase·GPS 없이 앱 전체를 띄운다.
Future<void> pumpApp(
  WidgetTester tester, {
  required AuthRepository authRepository,
  String nickname = '등산객AB12',
  AppDatabase? database,
  LocationService? location,
  ActivityRemote? remote,
  CourseRemote? courseRemote,
  CompetitionRemote? competition,
  ReviewRemote? reviews,
  SubscriptionRemote? subscription,
  GpxSharer? gpxSharer,
  AchievementRemote? achievements,
  PhotoPicker? photoPicker,
  ActivityPhotoRemote? activityPhotos,
  AvatarRemote? avatars,
  ProfileRemote? profiles,
  ClubRemote? clubs,
  ChatRemote? chats,
  ShopRemote? shop,
  DateTime Function()? clock,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(authRepository),
        myProfileProvider.overrideWith((ref) async {
          final user = ref.watch(currentUserProvider).value;
          return user == null ? null : Profile(id: user.id, nickname: nickname);
        }),
        appDatabaseProvider.overrideWithValue(database ?? testDatabase()),
        locationServiceProvider.overrideWithValue(
          location ?? FakeLocationService(),
        ),
        activityRemoteProvider.overrideWithValue(
          remote ?? FakeActivityRemote(),
        ),
        courseRemoteProvider.overrideWithValue(
          courseRemote ?? FakeCourseRemote(),
        ),
        competitionRemoteProvider.overrideWithValue(
          competition ?? FakeCompetitionRemote(),
        ),
        reviewRemoteProvider.overrideWithValue(reviews ?? FakeReviewRemote()),
        subscriptionRemoteProvider.overrideWithValue(
          subscription ?? FakeSubscriptionRemote(),
        ),
        gpxSharerProvider.overrideWithValue(gpxSharer ?? FakeGpxSharer()),
        recordingNotifierProvider.overrideWithValue(FakeRecordingNotifier()),
        achievementRemoteProvider.overrideWithValue(
          achievements ?? FakeAchievementRemote(),
        ),
        photoPickerProvider.overrideWithValue(photoPicker ?? FakePhotoPicker()),
        activityPhotoRemoteProvider.overrideWithValue(
          activityPhotos ?? FakeActivityPhotoRemote(),
        ),
        avatarRemoteProvider.overrideWithValue(avatars ?? FakeAvatarRemote()),
        clubRemoteProvider.overrideWithValue(clubs ?? FakeClubRemote()),
        chatRemoteProvider.overrideWithValue(chats ?? FakeChatRemote()),
        shopRemoteProvider.overrideWithValue(shop ?? FakeShopRemote()),
        profileRemoteProvider.overrideWithValue(
          profiles ?? FakeProfileRemote(),
        ),
        // 주소 검색(웹 화면) 대신 정해 둔 주소를 고른 것으로 한다.
        addressSearchProvider.overrideWithValue(
          (_) async => (postcode: '46241', address: '부산 금정구 부산대학로 63번길 2'),
        ),
        // 위젯 테스트에서는 지도 타일을 인터넷에서 받지 않는다.
        mapTilesEnabledProvider.overrideWithValue(false),
        if (clock != null) clockProvider.overrideWithValue(clock),
      ],
      child: const HikingApp(),
    ),
  );
  await tester.pumpAndSettle();
}
