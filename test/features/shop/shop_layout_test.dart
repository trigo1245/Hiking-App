import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiking_app/features/auth/domain/app_user.dart';
import 'package:hiking_app/features/shop/domain/shop.dart';

import '../../helpers/pump_app.dart';
import '../auth/fake_auth_repository.dart';
import 'fake_shop_remote.dart';

Product item(String id, ProductCategory category, {int? ad}) => Product(
  id: id,
  category: category,
  name: '상품 $id',
  description: '',
  price: 10000,
  adRank: ad,
);

void main() {
  // 광고 4개: 등산화 3개(광고 1·3·4번) + 배낭 1개(광고 2번)
  final products = [
    item('s1', ProductCategory.shoes, ad: 1),
    item('s2', ProductCategory.shoes, ad: 3),
    item('s3', ProductCategory.shoes, ad: 4),
    item('b1', ProductCategory.backpack, ad: 2),
    item('b2', ProductCategory.backpack),
    item('l1', ProductCategory.safety),
  ];
  List<String> ids(List<Product> ps) => [for (final p in ps) p.id];

  group('광고 칸', () {
    test('전체: 광고 순서대로 2개, 들어오지 못한 광고는 일반 목록에', () {
      final layout = ShopLayout.of(products);
      expect(ids(layout.ads), ['s1', 'b1']);
      expect(ids(layout.items), ['s2', 's3', 'b2', 'l1']);
    });

    test('들어올 때마다 다음 광고로 번갈아 채운다', () {
      expect(ids(ShopLayout.of(products, rotation: 1).ads), ['b1', 's2']);
      expect(ids(ShopLayout.of(products, rotation: 3).ads), ['s3', 's1']);
      expect(ids(ShopLayout.of(products, rotation: 4).ads), ['s1', 'b1']);
    });

    test('카테고리: 그 분류의 광고만 최대 2개, 광고 칸의 상품은 목록에 다시 나오지 않는다', () {
      final shoes = ShopLayout.of(
        products,
        category: ProductCategory.shoes,
        rotation: 1,
      );
      expect(ids(shoes.ads), ['s2', 's3']);
      expect(ids(shoes.items), ['s1']);

      final bags = ShopLayout.of(products, category: ProductCategory.backpack);
      expect(ids(bags.ads), ['b1']);
      expect(ids(bags.items), ['b2']);

      final safety = ShopLayout.of(products, category: ProductCategory.safety);
      expect(safety.ads, isEmpty);
      expect(ids(safety.items), ['l1']);
    });
  });

  testWidgets('☰로 카테고리를 고르면 그 분류 상품만 보이고, 광고에는 "광고" 표시', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpApp(
      tester,
      authRepository: FakeAuthRepository(
        user: const AppUser(id: 'u1', provider: SocialProvider.google),
      ),
      shop: FakeShopRemote(products: products),
    );
    Future<void> settle() async {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pumpAndSettle();
    }

    await settle();
    await tester.tap(find.text('쇼핑'));
    await settle();
    expect(find.text('광고'), findsNWidgets(2));
    expect(find.text('상품 l1'), findsOneWidget);

    await tester.tap(find.byTooltip('카테고리'));
    await settle();
    await tester.tap(find.text('배낭').last);
    await settle();

    expect(find.text('배낭'), findsOneWidget); // 제목
    expect(find.text('상품 b1'), findsOneWidget);
    expect(find.text('상품 b2'), findsOneWidget);
    expect(find.text('상품 s1'), findsNothing);
    expect(find.text('상품 l1'), findsNothing);
    expect(find.text('광고'), findsOneWidget);
  });
}
