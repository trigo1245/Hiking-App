import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiking_app/features/auth/domain/app_user.dart';
import 'package:hiking_app/features/auth/domain/profile_rules.dart';
import 'package:hiking_app/features/shop/domain/shop.dart';

import '../../helpers/pump_app.dart';
import '../auth/fake_auth_repository.dart';
import '../auth/fake_profile_remote.dart';
import 'fake_shop_remote.dart';

void main() {
  group('규칙', () {
    test('가격은 세 자리마다 쉼표', () {
      expect(formatPrice(129000), '129,000원');
      expect(formatPrice(9900), '9,900원');
      expect(formatPrice(500), '500원');
    });

    test('옵션 이름에 맞는 조사를 붙인다', () {
      expect(withObjectParticle('사이즈'), '사이즈를');
      expect(withObjectParticle('색상'), '색상을');
    });

    test('주문 요약과 배송 상태', () {
      expect(OrderStatus.parse('shipping'), OrderStatus.shipping);
      expect(OrderStatus.parse(null), OrderStatus.paid);
      final o = ShopOrder(
        id: 'o',
        productId: 'p',
        productName: '등산화',
        category: ProductCategory.shoes,
        art: 0,
        optionName: '사이즈',
        optionValue: '260',
        quantity: 2,
        totalPrice: 2,
        recipientName: '김',
        recipientPhone: '010',
        address: '부산',
        createdAt: DateTime(2026, 11, 2),
        status: OrderStatus.paid,
      );
      expect(o.summary, '사이즈 260 · 2개');
    });
  });

  group('화면', () {
    Future<void> settle(WidgetTester tester) async {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pumpAndSettle();
    }

    Future<void> openShop(
      WidgetTester tester,
      FakeShopRemote shop, {
      FakeProfileRemote? profiles,
    }) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpApp(
        tester,
        authRepository: FakeAuthRepository(
          user: const AppUser(id: 'u1', provider: SocialProvider.google),
        ),
        shop: shop,
        profiles: profiles,
      );
      await settle(tester);
      await tester.tap(find.text('쇼핑'));
      await settle(tester);
    }

    void clearSnack(WidgetTester tester) => tester
        .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger).first)
        .removeCurrentSnackBar();

    testWidgets('하단 탭은 쇼핑 / 동호회 / 홈 / 기록 / 내 정보 순서다', (tester) async {
      await openShop(tester, FakeShopRemote());
      final xs = [
        for (final label in ['쇼핑', '동호회', '홈', '기록', '내 정보'])
          tester.getCenter(find.text(label).last).dx,
      ];
      expect(xs, [...xs]..sort());
      expect(find.text('산길 경량 등산화'), findsOneWidget);
      expect(find.text('랜턴·안전'), findsOneWidget); // 분류 제목
    });

    testWidgets('사이즈를 골라 시연용 결제로 사고, 배송이 끝나면 리뷰를 쓴다', (tester) async {
      final shop = FakeShopRemote();
      final profiles = FakeProfileRemote()
        ..privateInfo = const PrivateInfo(
          name: '김등산',
          phone: '01012345678',
          postcode: '46241',
          address: '부산 금정구 부산대학로 63번길 2',
        );
      await openShop(tester, shop, profiles: profiles);

      await tester.tap(find.text('산길 경량 등산화'));
      await settle(tester);
      await tester.tap(find.text('129,000원 구매하기'));
      await settle(tester);
      expect(find.text('사이즈를 골라 주세요'), findsOneWidget);
      clearSnack(tester);

      await tester.tap(find.text('260'));
      await tester.pump();
      await tester.tap(find.text('129,000원 구매하기'));
      await settle(tester);

      // 주문서: 배송지는 개인정보에서, 수량을 늘리면 금액이 바뀐다
      expect(find.text('주문서'), findsOneWidget);
      expect(find.textContaining('김등산'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('수량 늘리기'));
      await tester.pump();
      await tester.tap(find.text('258,000원 결제하기'));
      await settle(tester);
      expect(find.text('주문했어요'), findsOneWidget);
      expect(shop.orders.single.quantity, 2);
      expect(shop.orders.single.optionValue, '260');

      await tester.tap(find.text('주문 내역 보기'));
      await settle(tester);
      expect(find.text('결제 완료'), findsOneWidget);
      expect(find.text('리뷰 쓰기'), findsNothing); // 배송 전에는 못 쓴다

      // 시간이 지나 배송 완료 → 화면이 15초마다 다시 받는다
      shop.deliverAll();
      await tester.pump(const Duration(seconds: 16));
      await settle(tester);
      expect(find.text('배송 완료'), findsOneWidget);

      await tester.tap(find.text('리뷰 쓰기'));
      await settle(tester);
      await tester.tap(find.bySemanticsLabel('별 5개'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), '발이 편해요');
      await tester.tap(find.text('저장하기'));
      await settle(tester);

      expect(find.text('내 리뷰 고치기'), findsOneWidget);
      expect(shop.reviews['trail-light-shoes']!.single.rating, 5);
    });

    testWidgets('상품 상세에서 다른 사람의 리뷰를 별점 높은 순으로 본다', (tester) async {
      final shop = FakeShopRemote()
        ..reviews['headlamp-400'] = [
          ProductReview(
            nickname: '산딸기',
            nicknameTag: '0021',
            rating: 3,
            comment: '보통이에요',
            createdAt: DateTime(2026, 11, 1),
          ),
          ProductReview(
            nickname: '고당봉지킴이',
            nicknameTag: '0002',
            rating: 5,
            comment: '밝아요',
            createdAt: DateTime(2026, 10, 1),
          ),
        ];
      await openShop(tester, shop);
      expect(find.text('4.0 (2)'), findsOneWidget);

      await tester.tap(find.text('헤드랜턴 400루멘'));
      await settle(tester);
      expect(find.text('리뷰 2'), findsOneWidget);
      expect(find.text('리뷰 쓰기'), findsNothing); // 산 적이 없다
      double y(String t) => tester.getTopLeft(find.text(t)).dy;
      expect(y('보통이에요'), lessThan(y('밝아요'))); // 최신순

      await tester.tap(find.text('별점 높은 순'));
      await settle(tester);
      expect(y('밝아요'), lessThan(y('보통이에요')));
    });
  });
}
