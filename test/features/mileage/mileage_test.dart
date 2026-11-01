import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiking_app/app/routes.dart';
import 'package:go_router/go_router.dart';
import 'package:hiking_app/features/achievements/domain/achievements.dart';
import 'package:hiking_app/features/auth/domain/app_user.dart';
import 'package:hiking_app/features/mileage/domain/mileage.dart';

import '../../helpers/pump_app.dart';
import '../auth/fake_auth_repository.dart';
import 'fake_mileage_remote.dart';

void main() {
  group('규칙', () {
    test('프리미엄은 1.5배(올림), 배지는 단계 색으로 30·50·100', () {
      const rule = MileageRule('코스 완주', 30, '');
      expect(rule.amountFor(premium: false), 30);
      expect(rule.amountFor(premium: true), 45);
      expect(const MileageRule('산행', 15, '').amountFor(premium: true), 23);
      expect(badgeMileage(BadgeTier.bronze), 30);
      expect(badgeMileage(BadgeTier.gold), 100);
    });

    test('얻은 배지의 단계마다 알린다 (2단계 배지는 동·금)', () {
      final achievements = Achievements(
        badges: [
          BadgeStatus(
            def: Badges.firstStep,
            value: 1,
            achievedAt: [DateTime(2026, 10, 1)],
          ),
          for (final b in Badges.all)
            if (b.levels == 2)
              BadgeStatus(
                def: b,
                value: 99,
                achievedAt: [DateTime(2026, 10, 1), DateTime(2026, 10, 2)],
              ),
        ].take(2).toList(),
        seasons: const [],
      );
      final claims = badgeClaimsOf(achievements);
      expect(claims.first.id, 'first_step');
      expect(claims.first.tier, BadgeTier.gold);
      expect(
        [for (final c in claims.skip(1)) c.tier],
        [BadgeTier.bronze, BadgeTier.gold],
      );
    });

    test('천 단위 쉼표', () {
      expect(formatMileage(1800), '1,800');
      expect(formatMileage(-500), '-500');
    });
  });

  group('화면', () {
    Future<void> settle(WidgetTester tester) async {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pumpAndSettle();
    }

    Future<void> open(WidgetTester tester, FakeMileageRemote mileage) async {
      tester.view.physicalSize = const Size(800, 2600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpApp(
        tester,
        authRepository: FakeAuthRepository(
          user: const AppUser(id: 'u1', provider: SocialProvider.google),
        ),
        mileage: mileage,
      );
      await settle(tester);
    }

    testWidgets('잔액이 모자란 교환권은 누를 수 없고, 7일권을 바꾸면 잔액과 내역이 바뀐다', (tester) async {
      final mileage = FakeMileageRemote(balance: 650);
      await open(tester, mileage);
      GoRouter.of(tester.element(find.text('등산 기록 시작')))
          .push(AppRoutes.mileage);
      await settle(tester);

      final start = mileage.balance;
      expect(find.text('프리미엄 7일 교환권'), findsOneWidget);
      expect(
        find.textContaining('${formatMileage(1800 - start)} 더 모으면 돼요'),
        findsOneWidget,
      );

      await tester.tap(find.text('교환하기').first);
      await settle(tester);
      expect(find.text('프리미엄 7일 교환권으로 바꿀까요?'), findsOneWidget);
      await tester.tap(find.text('교환하기').last);
      await settle(tester);

      expect(mileage.redeemed, [MileageReward.week]);
      expect(
        find.textContaining(
          '${formatMileage(start - 500)} 마일리지',
          findRichText: true,
        ),
        findsWidgets,
      );
      expect(find.text('-500'), findsOneWidget);
    });

    testWidgets('서버가 적립하면 어느 화면에서든 "+N 마일리지를 받았어요"를 알린다', (tester) async {
      final mileage = FakeMileageRemote();
      await open(tester, mileage);
      tester
          .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger).first)
          .removeCurrentSnackBar();
      await tester.pump();

      mileage.earn(45, '코스 완주 · 금정산 범어사');
      await tester.pump(const Duration(seconds: 1));
      await settle(tester);
      expect(find.text('+45 마일리지를 받았어요'), findsOneWidget);
    });
  });
}
