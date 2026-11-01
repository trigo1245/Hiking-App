import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hiking_app/app/routes.dart';
import 'package:hiking_app/core/widgets/app_button.dart';
import 'package:hiking_app/features/auth/domain/app_user.dart';
import 'package:hiking_app/features/auth/domain/profile.dart';
import 'package:hiking_app/features/auth/domain/profile_rules.dart';
import 'package:hiking_app/features/auth/presentation/private_info_screen.dart';
import 'package:hiking_app/features/courses/domain/competition.dart';

import '../../helpers/pump_app.dart';
import '../courses/fake_competition_remote.dart';
import '../courses/fake_course_remote.dart';
import '../fakes_phase2.dart';
import 'fake_auth_repository.dart';
import 'fake_profile_remote.dart';

void main() {
  group('입력 규칙', () {
    test('닉네임은 2~10자 한글·영문·숫자', () {
      expect(nicknameError('등산왕'), isNull);
      expect(nicknameError('Hiker99'), isNull);
      expect(nicknameError('산'), isNotNull);
      expect(nicknameError('열한글자닉네임입니다요'), isNotNull);
      expect(nicknameError('산 왕'), contains('띄어쓰기'));
      expect(nicknameError('산왕!'), isNotNull);
    });

    test('휴대폰 번호는 숫자만 저장하고, 보여 줄 때 하이픈을 넣는다', () {
      expect(normalizePhone('010-1234-5678'), '01012345678');
      expect(formatPhone('01012345678'), '010-1234-5678');
      expect(formatPhone('0111234567'), '011-123-4567');
      expect(phoneError(''), isNull); // 비워 둬도 된다.
      expect(phoneError('010-1234'), isNotNull);
      expect(phoneError('02-123-4567'), isNotNull);
    });

    test('기능이 요구한 항목 중 빠진 것을 찾는다', () {
      const info = PrivateInfo(name: '김세민', phone: '0101234');
      expect(info.missing(PrivateField.values.toSet()), [
        PrivateField.phone,
        PrivateField.address,
      ]);
      expect(info.missing({PrivateField.name}), isEmpty);
      expect(info.summary, '이름 입력함');
      expect(const PrivateInfo().summary, '아직 입력하지 않았어요');
    });

    test('우편번호 서비스 결과에서 고른 쪽 주소를 꺼낸다', () {
      expect(
        addressFromPostcode({
          'zonecode': '46241',
          'userSelectedType': 'R',
          'roadAddress': '부산 금정구 부산대학로63번길 2',
          'jibunAddress': '부산 금정구 장전동 30',
          'buildingName': '부산대학교',
        }),
        (postcode: '46241', address: '부산 금정구 부산대학로63번길 2 (부산대학교)'),
      );
      expect(
        addressFromPostcode({
          'zonecode': '46241',
          'userSelectedType': 'J',
          'roadAddress': '부산 금정구 부산대학로63번길 2',
          'jibunAddress': '부산 금정구 장전동 30',
          'buildingName': '부산대학교',
        })?.address,
        '부산 금정구 장전동 30',
      );
      expect(addressFromPostcode({'zonecode': ''}), isNull);
    });
  });

  group('화면', () {
    FakeAuthRepository signedIn() => FakeAuthRepository(
      user: const AppUser(id: 'u1', provider: SocialProvider.google),
    );

    void tallScreen(WidgetTester tester) {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }

    Future<void> settle(WidgetTester tester) async {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pumpAndSettle();
    }

    Future<FakeProfileRemote> openMyInfo(
      WidgetTester tester, {
      FakeProfileRemote? profiles,
    }) async {
      tallScreen(tester);
      final remote = profiles ?? FakeProfileRemote();
      await pumpApp(tester, authRepository: signedIn(), profiles: remote);
      await settle(tester);
      await tester.tap(find.text('내 정보'));
      await settle(tester);
      return remote;
    }

    testWidgets('프로필 편집: 규칙에 맞지 않는 닉네임은 저장할 수 없고, 소개·지역과 함께 저장한다', (
      tester,
    ) async {
      final remote = await openMyInfo(tester);
      await tester.tap(find.text('등산객AB12'));
      await settle(tester);

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), '산 왕');
      await tester.pump();
      expect(find.textContaining('띄어쓰기'), findsOneWidget);
      expect(
        tester.widget<AppButton>(find.byType(AppButton)).onPressed,
        isNull,
      );

      await tester.enterText(fields.at(0), '등산왕');
      await tester.enterText(fields.at(1), '주말마다 금정산에 가요');
      await tester.enterText(fields.at(2), '부산 금정구');
      await tester.pump();
      await tester.tap(find.text('저장하기'));
      await settle(tester);

      expect(remote.updates.single, ('등산왕', '주말마다 금정산에 가요', '부산 금정구'));
      expect(find.text('프로필을 저장했어요'), findsOneWidget);
    });

    testWidgets('개인정보 관리: 휴대폰 번호를 확인하고, 주소 검색으로 주소를 채워 저장한다', (tester) async {
      final remote = await openMyInfo(tester);
      expect(find.textContaining('아직 입력하지 않았어요'), findsOneWidget);
      await tester.tap(find.text('개인정보 관리'));
      await settle(tester);

      expect(find.textContaining('나만 볼 수 있어요'), findsOneWidget);
      await tester.enterText(find.byType(TextField).at(1), '010-12');
      await tester.pump();
      expect(find.textContaining('휴대폰 번호를 확인해 주세요'), findsOneWidget);

      await tester.enterText(find.byType(TextField).at(0), '김세민');
      await tester.enterText(find.byType(TextField).at(1), '010-1234-5678');
      await tester.tap(find.text('주소 검색'));
      await settle(tester);
      expect(find.text('부산 금정구 부산대학로 63번길 2'), findsOneWidget);
      await tester.enterText(find.byType(TextField).at(2), '101호');
      await tester.pump();
      await tester.tap(find.text('저장하기'));
      await settle(tester);

      expect(remote.privateInfo.phone, '01012345678');
      expect(remote.privateInfo.postcode, '46241');
      expect(remote.privateInfo.addressDetail, '101호');
      expect(find.textContaining('이름·휴대폰 번호·주소 입력함'), findsOneWidget);
    });

    testWidgets('개인정보를 불러오지 못하면 계속 기다리지 않고 다시 시도 버튼을 보여 준다', (tester) async {
      await openMyInfo(
        tester,
        profiles: FakeProfileRemote()..failPrivate = true,
      );
      await tester.tap(find.text('개인정보 관리'));
      await settle(tester);

      expect(find.text('개인정보를 불러오지 못했어요'), findsOneWidget);
      expect(find.text('다시 시도'), findsOneWidget);
    });

    testWidgets('기능이 개인정보를 요구하면 이유를 알리고, 필요한 항목을 다 채워야 계속한다', (tester) async {
      tallScreen(tester);
      final remote = FakeProfileRemote()
        ..privateInfo = const PrivateInfo(name: '김세민');
      await pumpApp(tester, authRepository: signedIn(), profiles: remote);
      await settle(tester);

      final result = requirePrivateInfo(
        tester.element(find.text('등산 기록 시작')),
        fields: PrivateField.values.toSet(),
        purpose: '포토북 배송',
      );
      await settle(tester);
      expect(find.text('포토북 배송에 필요한 정보가 있어요'), findsOneWidget);
      expect(find.textContaining('휴대폰 번호, 주소을(를) 입력하면'), findsOneWidget);
      await tester.tap(find.text('입력하기'));
      await settle(tester);

      // 이름은 이미 있고, 빠진 항목만 "입력해 주세요"로 표시된다.
      expect(find.text('필수'), findsOneWidget);
      expect(find.text('필수 · 입력해 주세요'), findsNWidgets(2));
      expect(find.text('휴대폰 번호, 주소을(를) 입력해 주세요'), findsOneWidget);

      await tester.enterText(find.byType(TextField).at(1), '01012345678');
      await tester.tap(find.text('주소 검색'));
      await settle(tester);
      await tester.tap(find.text('저장하고 계속하기'));
      await settle(tester);

      expect(await result, isTrue);
      expect(remote.privateSaves, 1);
    });

    testWidgets('이미 다 입력했으면 묻지 않고 바로 계속한다', (tester) async {
      tallScreen(tester);
      final remote = FakeProfileRemote()
        ..privateInfo = const PrivateInfo(
          name: '김세민',
          phone: '01012345678',
          postcode: '46241',
          address: '부산 금정구',
        );
      await pumpApp(tester, authRepository: signedIn(), profiles: remote);
      await settle(tester);

      final ok = await requirePrivateInfo(
        tester.element(find.text('등산 기록 시작')),
        fields: PrivateField.values.toSet(),
        purpose: '포토북 배송',
      );
      expect(ok, isTrue);
      expect(find.text('포토북 배송에 필요한 정보가 있어요'), findsNothing);
    });

    testWidgets('리뷰 작성자를 누르면 공개 프로필(지역·소개)만 보인다', (tester) async {
      tallScreen(tester);
      final remote = FakeProfileRemote()
        ..publicProfiles['고당봉지킴이#0001'] = const PublicProfile(
          nickname: '고당봉지킴이',
          nicknameTag: '0001',
          bio: '고당봉 일출을 좋아해요',
          region: '부산 금정구',
        );
      await pumpApp(
        tester,
        authRepository: signedIn(),
        courseRemote: FakeCourseRemote([testCourse(id: 'a')]),
        competition: FakeCompetitionRemote()
          ..stats = const CourseStats(completionCount: 10),
        reviews: FakeReviewRemote()..reviews.add(review('고당봉지킴이', 4)),
        profiles: remote,
      );
      await settle(tester);
      GoRouter.of(tester.element(find.text('등산 기록 시작')))
          .push(AppRoutes.course('a'));
      await settle(tester);

      await tester.tap(find.text('고당봉지킴이#0001'));
      await settle(tester);

      expect(find.text('고당봉 일출을 좋아해요'), findsOneWidget);
      expect(find.text('부산 금정구'), findsOneWidget);
      expect(find.text('내 프로필 편집'), findsNothing);
      // 다른 사람이면 1:1 메시지를 보낼 수 있다.
      expect(find.text('메시지 보내기'), findsOneWidget);
    });
  });
}
