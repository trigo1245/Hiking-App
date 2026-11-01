import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hiking_app/app/routes.dart';
import 'package:hiking_app/core/database/app_database.dart';
import 'package:hiking_app/core/photos/photo_picker.dart';
import 'package:hiking_app/core/photos/photo_spec.dart';
import 'package:hiking_app/features/activities/data/activities_repository.dart';
import 'package:hiking_app/features/activities/data/demo_activity_generator.dart';
import 'package:hiking_app/features/activities/domain/activity_deletion.dart';
import 'package:hiking_app/features/activities/domain/activity_summary.dart';
import 'package:hiking_app/features/auth/domain/app_user.dart';
import 'package:hiking_app/features/courses/domain/competition.dart';
import 'package:hiking_app/features/courses/domain/course.dart';
import 'package:hiking_app/features/courses/domain/review.dart';
import 'package:hiking_app/features/recording/data/recording_repository.dart';

import '../helpers/course_walk.dart';
import '../helpers/pump_app.dart';
import 'auth/fake_auth_repository.dart';
import 'courses/fake_competition_remote.dart';
import 'courses/fake_course_remote.dart';
import 'fakes_phase2.dart';
import 'photo_fakes.dart';

Course beomeosa() {
  final c = loadCourse('geumjeongsan-beomeosa');
  return Course(
    id: 'beomeosa',
    mountainName: '금정산',
    name: '범어사 코스',
    startName: '범어사',
    endName: '고당봉',
    distanceM: 2800,
    officialTimeMin: 50,
    path: c.path,
    summit: c.summit,
  );
}

void main() {
  DateTime clock() => DateTime(2026, 10, 20, 12);

  FakeAuthRepository signedIn() => FakeAuthRepository(
    user: const AppUser(id: 'u1', provider: SocialProvider.google),
  );

  void tallScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    await tester.pumpAndSettle();
  }

  Future<void> push(WidgetTester tester, String location) async {
    GoRouter.of(tester.element(find.text('등산 기록 시작'))).push(location);
    await settle(tester);
  }

  group('사진 기준', () {
    test('기록 10장·리뷰 3장·프로필 1장까지, 남은 장수만큼 더 고른다', () {
      expect(PhotoSpec.activity.maxCount, 10);
      expect(PhotoSpec.review.maxCount, 3);
      expect(PhotoSpec.avatar.maxCount, 1);
      expect(PhotoSpec.activity.remaining(7), 3);
      expect(PhotoSpec.review.remaining(5), 0);
      // 여러 사람이 보는 리뷰 사진은 더 작게 줄인다.
      expect(
        PhotoSpec.review.maxLongSide,
        lessThan(PhotoSpec.activity.maxLongSide),
      );
    });

    test('사진이 있는 기록을 지우면 사진도 함께 지워진다고 알린다', () {
      final summary = ActivitySummary(
        id: 'a1',
        title: '등산',
        startedAt: DateTime(2026, 10, 1),
        endedAt: DateTime(2026, 10, 1, 3),
        elapsed: const Duration(hours: 3),
        moving: const Duration(hours: 2),
        distanceM: 5000,
        elevationGainM: 300,
        maxAltitudeM: 500,
        pointCount: 10,
        isFlagged: false,
        uploadStatus: UploadStatus.done,
      );
      List<String> titles(int photos) => [
        for (final n in deletionNotices(
          summary: summary,
          completedCourses: const [],
          attemptedCourses: const [],
          photoCount: photos,
        ))
          n.title,
      ];
      expect(titles(3), contains('사진 3장도 함께 지워져요'));
      expect(titles(0).where((t) => t.contains('사진')), isEmpty);
    });
  });

  group('산행 기록 사진 (본인만, 프리미엄)', () {
    /// 서버에 올라간 범어사 완주 기록 하나
    Future<(AppDatabase, String)> uploadedHike(WidgetTester tester) async {
      final db = testDatabase();
      late String id;
      await tester.runAsync(() async {
        final ids = await DemoActivityGenerator(
          RecordingRepository(db),
          ActivitiesRepository(db),
        ).createDemoHikes(courses: demoCourses(), userId: 'u1', now: clock());
        id = ids.last;
        await ActivitiesRepository(db)
            .setUploadStatus(id, UploadStatus.done, userId: 'u1');
      });
      return (db, id);
    }

    testWidgets('구독자는 사진을 골라 올리고, 크게 보다가 지울 수 있다', (tester) async {
      tallScreen(tester);
      final (db, id) = await uploadedHike(tester);
      final picker = FakePhotoPicker(count: 2);
      final photos = FakeActivityPhotoRemote();
      await pumpApp(
        tester,
        authRepository: signedIn(),
        database: db,
        courseRemote: FakeCourseRemote([beomeosa()]),
        subscription: FakeSubscriptionRemote(active: true),
        photoPicker: picker,
        activityPhotos: photos,
        clock: clock,
      );
      await settle(tester);
      await push(tester, AppRoutes.activity(id));

      expect(find.text('나만 볼 수 있어요'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.add_a_photo_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.text('앨범에서 고르기'));
      await settle(tester);

      // 10장 중 남은 만큼 고르게 하고, 활동 기준(1600px)으로 줄인다.
      expect(picker.requests.single.$1, PhotoSource.gallery);
      expect(picker.requests.single.$2, PhotoSpec.activity);
      expect(picker.requests.single.$3, 10);
      expect(photos.photos[id], hasLength(2));
      expect(find.text('2 / 10'), findsOneWidget);
      expect(find.text('사진 2장을 올렸어요'), findsOneWidget);

      // 첫 사진을 크게 보고 지운다.
      await tester.tap(find.byType(Image).first);
      await tester.pumpAndSettle();
      expect(find.text('1 / 2'), findsOneWidget);
      await tester.tap(find.byTooltip('사진 지우기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('지우기'));
      await settle(tester);

      expect(photos.photos[id], hasLength(1));
      expect(find.text('1 / 10'), findsOneWidget);
    });

    testWidgets('일반 사용자는 사진을 올릴 수 없고 프리미엄 안내를 본다', (tester) async {
      tallScreen(tester);
      final (db, id) = await uploadedHike(tester);
      await pumpApp(
        tester,
        authRepository: signedIn(),
        database: db,
        courseRemote: FakeCourseRemote([beomeosa()]),
        clock: clock,
      );
      await settle(tester);
      await push(tester, AppRoutes.activity(id));

      expect(find.text('산행 사진 올리기는 프리미엄에서 할 수 있어요'), findsOneWidget);
      expect(find.byIcon(Icons.add_a_photo_outlined), findsNothing);
    });
  });

  testWidgets('리뷰에 사진을 3장까지 붙이고, 저장하면 올린다', (tester) async {
    tallScreen(tester);
    final reviews = FakeReviewRemote();
    final picker = FakePhotoPicker(count: 5);
    await pumpApp(
      tester,
      authRepository: signedIn(),
      courseRemote: FakeCourseRemote([testCourse(id: 'a')]),
      competition: FakeCompetitionRemote()
        ..stats = const CourseStats(completionCount: 10, myCount: 1),
      reviews: reviews,
      photoPicker: picker,
      clock: clock,
    );
    await settle(tester);
    await push(tester, AppRoutes.course('a'));
    await tester.tap(find.text('리뷰 쓰기'));
    await settle(tester);

    for (final aspect in ReviewAspect.values) {
      await tester.tap(find.bySemanticsLabel('${aspect.label} 4점'));
    }
    expect(find.text('리뷰 사진은 모든 사람이 볼 수 있어요'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.add_a_photo_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('사진 찍기'));
    await settle(tester);

    // 리뷰 기준(3장)만큼만 받고, 다 차면 더 고를 수 없다.
    expect(picker.requests.single.$1, PhotoSource.camera);
    expect(picker.requests.single.$3, 3);
    expect(find.text('3 / 3'), findsOneWidget);
    expect(find.byIcon(Icons.add_a_photo_outlined), findsNothing);

    // 하나 빼고 저장한다.
    await tester.tap(find.byIcon(Icons.close_rounded).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('저장하기'));
    await settle(tester);

    expect(reviews.saved, hasLength(1));
    expect(reviews.myPhotos, hasLength(2));
  });

  testWidgets('내 정보에서 프로필 사진을 바꾼다', (tester) async {
    final avatars = FakeAvatarRemote();
    final picker = FakePhotoPicker(count: 1);
    await pumpApp(
      tester,
      authRepository: signedIn(),
      photoPicker: picker,
      avatars: avatars,
      clock: clock,
    );
    await settle(tester);
    await tester.tap(find.text('내 정보'));
    await settle(tester);

    await tester.tap(find.byIcon(Icons.photo_camera_rounded));
    await tester.pumpAndSettle();
    // 직접 올린 사진이 없으면 되돌리기는 보이지 않는다.
    expect(find.text('카카오·구글 사진으로 되돌리기'), findsNothing);
    await tester.tap(find.text('앨범에서 고르기'));
    await settle(tester);

    expect(picker.requests.single.$2, PhotoSpec.avatar);
    expect(avatars.uploads, 1);
    expect(find.text('프로필 사진을 바꿨어요'), findsOneWidget);
  });
}
