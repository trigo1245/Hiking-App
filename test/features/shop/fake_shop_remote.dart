import 'dart:typed_data';

import 'package:hiking_app/core/photos/photo_item.dart';
import 'package:hiking_app/features/shop/data/shop_remote.dart';
import 'package:hiking_app/features/shop/domain/shop.dart';

/// 서버 대신 상품·주문·리뷰를 기억하는 가짜. 나는 등산객AB12#0369.
/// 배송 상태는 [deliverAll]로 바꾼다 (서버는 주문 시각으로 계산한다).
class FakeShopRemote implements ShopRemote {
  FakeShopRemote({List<Product>? products})
    : products = products ?? [boots, lamp];

  static const boots = Product(
    id: 'trail-light-shoes',
    category: ProductCategory.shoes,
    name: '산길 경량 등산화',
    description: '가벼운 등산화예요.',
    price: 129000,
    optionName: '사이즈',
    options: ['250', '260', '270'],
  );

  static const lamp = Product(
    id: 'headlamp-400',
    category: ProductCategory.safety,
    name: '헤드랜턴 400루멘',
    description: '머리 랜턴이에요.',
    price: 35000,
    art: 9,
  );

  final List<Product> products;
  final orders = <ShopOrder>[];
  final reviews = <String, List<ProductReview>>{};
  final myPhotos = <String, List<PhotoItem>>{};
  var _next = 0;

  /// 내 주문을 모두 배송 완료로 바꾼다.
  void deliverAll() {
    for (var i = 0; i < orders.length; i++) {
      orders[i] = _copy(orders[i], status: OrderStatus.delivered);
    }
  }

  ShopOrder _copy(ShopOrder o, {OrderStatus? status, bool? hasReview}) =>
      ShopOrder(
        id: o.id,
        productId: o.productId,
        productName: o.productName,
        category: o.category,
        art: o.art,
        optionName: o.optionName,
        optionValue: o.optionValue,
        quantity: o.quantity,
        totalPrice: o.totalPrice,
        recipientName: o.recipientName,
        recipientPhone: o.recipientPhone,
        address: o.address,
        createdAt: o.createdAt,
        status: status ?? o.status,
        hasReview: hasReview ?? o.hasReview,
      );

  ProductReview? _mine(String productId) =>
      reviews[productId]?.where((r) => r.isMine).firstOrNull;

  @override
  Future<List<Product>> fetchProducts() async => [
    for (final p in products)
      Product(
        id: p.id,
        category: p.category,
        name: p.name,
        description: p.description,
        price: p.price,
        optionName: p.optionName,
        options: p.options,
        art: p.art,
        ratingAvg: (reviews[p.id] ?? const []).isEmpty
            ? null
            : reviews[p.id]!.map((r) => r.rating).reduce((a, b) => a + b) /
                  reviews[p.id]!.length,
        reviewCount: reviews[p.id]?.length ?? 0,
        adRank: p.adRank,
      ),
  ];

  @override
  Future<String> placeOrder(
    String productId, {
    String? option,
    int quantity = 1,
  }) async {
    final p = products.firstWhere((p) => p.id == productId);
    final id = 'o${++_next}';
    orders.insert(
      0,
      ShopOrder(
        id: id,
        productId: p.id,
        productName: p.name,
        category: p.category,
        art: p.art,
        optionName: p.optionName,
        optionValue: option,
        quantity: quantity,
        totalPrice: p.price * quantity,
        recipientName: '김등산',
        recipientPhone: '01012345678',
        address: '부산 금정구 부산대학로 63번길 2',
        createdAt: DateTime(2026, 11, 2, 10),
        status: OrderStatus.paid,
      ),
    );
    return id;
  }

  @override
  Future<List<ShopOrder>> fetchMyOrders() async => [
    for (final o in orders) _copy(o, hasReview: _mine(o.productId) != null),
  ];

  @override
  Future<ProductReviewPage> fetchReviews(
    String productId, {
    ProductReviewSort sort = ProductReviewSort.recent,
    int offset = 0,
    int limit = 30,
  }) async {
    final list = [...?reviews[productId]];
    if (sort == ProductReviewSort.rating) {
      list.sort((a, b) => b.rating.compareTo(a.rating));
    }
    return ProductReviewPage(reviews: list, total: list.length);
  }

  @override
  Future<MyProductReview> fetchMyReview(String productId) async {
    final mine = _mine(productId);
    return MyProductReview(
      canReview: orders.any(
        (o) => o.productId == productId && o.status == OrderStatus.delivered,
      ),
      rating: mine?.rating,
      comment: mine?.comment,
      photos: [...?myPhotos[productId]],
    );
  }

  @override
  Future<void> saveMyReview(
    String productId,
    int rating,
    String comment,
  ) async {
    final list = reviews.putIfAbsent(productId, () => []);
    list.removeWhere((r) => r.isMine);
    list.insert(
      0,
      ProductReview(
        nickname: '등산객AB12',
        nicknameTag: '0369',
        rating: rating,
        comment: comment.isEmpty ? null : comment,
        createdAt: DateTime(2026, 11, 2, 11),
        isMine: true,
      ),
    );
  }

  @override
  Future<void> deleteMyReview(String productId) async {
    reviews[productId]?.removeWhere((r) => r.isMine);
    myPhotos.remove(productId);
  }

  @override
  Future<void> addReviewPhoto(String productId, Uint8List jpeg) async {
    final id = 'p${++_next}';
    myPhotos
        .putIfAbsent(productId, () => [])
        .add(PhotoItem(id: id, path: id, url: 'https://example.com/$id.jpg'));
  }

  @override
  Future<void> deleteReviewPhoto(PhotoItem photo) async {
    for (final list in myPhotos.values) {
      list.removeWhere((p) => p.id == photo.id);
    }
  }
}
