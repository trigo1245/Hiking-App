import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiking_app/features/auth/domain/app_user.dart';
import 'package:hiking_app/features/recording/data/location_service.dart';
import 'package:hiking_app/features/recording/domain/track_point.dart';

import '../../../helpers/pump_app.dart';
import '../../auth/fake_auth_repository.dart';
import '../../courses/fake_course_remote.dart';
import '../../recording/fake_location_service.dart';

void main() {
  FakeAuthRepository signedIn() => FakeAuthRepository(
    user: const AppUser(id: 'u1', provider: SocialProvider.kakao),
  );

  final courses = FakeCourseRemote([
    testCourse(id: 'a', mountainName: '승학산', name: '동아대 코스'),
    testCourse(id: 'b', mountainName: '금정산', name: '범어사 코스'),
  ]);

  /// 코스 받기(DB 저장)가 끝나도록 실제 시간으로 잠깐 기다린다.
  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('홈은 지도와 검색창, 등산 기록 시작 버튼, 출처 표시가 있다', (tester) async {
    await pumpApp(tester, authRepository: signedIn(), courseRemote: courses);
    await settle(tester);

    expect(find.text('산, 코스 이름으로 검색'), findsOneWidget);
    expect(find.text('등산 기록 시작'), findsOneWidget);
    expect(find.textContaining('OpenStreetMap'), findsOneWidget);
    // 정상 표시 (서버에서 받아 기기에 저장한 코스)
    expect(find.text('▲ 승학산'), findsOneWidget);
    expect(find.text('▲ 금정산'), findsOneWidget);
  });

  testWidgets('검색해서 코스를 고르면 코스 카드가 뜬다', (tester) async {
    await pumpApp(tester, authRepository: signedIn(), courseRemote: courses);
    await settle(tester);

    await tester.enterText(find.byType(TextField), '금정');
    await tester.pumpAndSettle();
    expect(find.text('금정산 범어사 코스'), findsOneWidget);
    expect(find.text('승학산 동아대 코스'), findsNothing);

    await tester.tap(find.text('금정산 범어사 코스'));
    await tester.pumpAndSettle();

    // 검색창이 비워지고 카드가 뜬다.
    expect(find.text('금정산 범어사 코스'), findsOneWidget);
    expect(find.textContaining('1.04 km'), findsOneWidget);
    expect(find.textContaining('오르막 약 18분'), findsOneWidget);
  });

  testWidgets('찾는 코스가 없으면 안내한다', (tester) async {
    await pumpApp(tester, authRepository: signedIn(), courseRemote: courses);
    await settle(tester);

    await tester.enterText(find.byType(TextField), '한라산');
    await tester.pumpAndSettle();
    expect(find.text('찾는 코스가 없어요'), findsOneWidget);
  });

  testWidgets('내 위치 버튼: 권한이 없으면 안내하고, 있으면 위치를 받기 시작한다', (tester) async {
    final location = FakeLocationService(access: LocationAccess.denied);
    await pumpApp(tester, authRepository: signedIn(), location: location);
    await settle(tester);

    await tester.tap(find.bySemanticsLabel('내 위치'));
    await tester.pumpAndSettle();
    expect(find.text('내 위치를 보려면 정확한 위치 권한이 필요해요'), findsOneWidget);

    location.access = LocationAccess.granted;
    await tester.tap(find.bySemanticsLabel('내 위치'));
    await tester.pumpAndSettle();
    location.emitMapPosition(
      LocationSample(
        latitude: 35.1168,
        longitude: 128.9798,
        accuracy: 5,
        recordedAt: DateTime(2026, 10, 20),
      ),
    );
    await tester.pumpAndSettle();
    // 기록용 위치 수집(상단 알림)은 시작하지 않는다.
    expect(location.isListening, isFalse);
  });
}
