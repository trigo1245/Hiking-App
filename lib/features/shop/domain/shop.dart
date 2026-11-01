/// 쇼핑 (일반 사용자 화면만, 시연용 결제): 상품·주문·상품 리뷰 모델과 규칙.
library;

import '../../../core/photos/photo_item.dart';

/// 상품 분류
enum ProductCategory {
  shoes('등산화'),
  backpack('배낭'),
  poles('스틱'),
  clothing('의류'),
  safety('랜턴·안전');

  const ProductCategory(this.label);
  final String label;

  static ProductCategory parse(String? value) => ProductCategory.values
      .firstWhere((c) => c.name == value, orElse: () => ProductCategory.safety);
}

class Product {
  const Product({
    required this.id,
    required this.category,
    required this.name,
    required this.description,
    required this.price,
    this.optionName,
    this.options = const [],
    this.art = 0,
    this.ratingAvg,
    this.reviewCount = 0,
    this.adRank,
  });

  final String id;
  final ProductCategory category;
  final String name;
  final String description;

  /// 원
  final int price;

  /// 고르는 옵션 이름(예: 사이즈). 옵션이 없는 상품은 null.
  final String? optionName;
  final List<String> options;

  /// 상품 카드 그림의 색 번호
  final int art;

  /// 리뷰가 없으면 null
  final double? ratingAvg;
  final int reviewCount;

  /// 광고 순서 (작을수록 먼저). null이면 광고가 아니다.
  final int? adRank;

  bool get isAd => adRank != null;
  bool get hasOptions => options.isNotEmpty;
}

/// 한 번에 살 수 있는 최대 수량 (서버 place_order와 같다)
const maxOrderQuantity = 5;

/// 상품 리뷰 후기 최대 글자 수 (서버와 같다)
const productReviewMaxLength = 200;

/// 시연용 배송 상태. 서버가 주문 시각으로 계산한다(1분 결제 완료 → 2분 배송 중 → 배송 완료).
enum OrderStatus {
  paid('결제 완료'),
  shipping('배송 중'),
  delivered('배송 완료');

  const OrderStatus(this.label);
  final String label;

  static OrderStatus parse(String? value) => OrderStatus.values.firstWhere(
    (s) => s.name == value,
    orElse: () => OrderStatus.paid,
  );
}

class ShopOrder {
  const ShopOrder({
    required this.id,
    required this.productId,
    required this.productName,
    required this.category,
    required this.art,
    required this.quantity,
    required this.totalPrice,
    required this.recipientName,
    required this.recipientPhone,
    required this.address,
    required this.createdAt,
    required this.status,
    this.optionName,
    this.optionValue,
    this.postcode,
    this.addressDetail,
    this.hasReview = false,
  });

  final String id;
  final String productId;
  final String productName;
  final ProductCategory category;
  final int art;
  final String? optionName;
  final String? optionValue;
  final int quantity;
  final int totalPrice;
  final String recipientName;
  final String recipientPhone;
  final String? postcode;
  final String address;
  final String? addressDetail;
  final DateTime createdAt;
  final OrderStatus status;

  /// 이 상품에 내 리뷰가 이미 있는지
  final bool hasReview;

  /// 예: "사이즈 260 · 1개"
  String get summary => [
    if (optionName != null && optionValue != null) '$optionName $optionValue',
    '$quantity개',
  ].join(' · ');
}

class ProductReview {
  const ProductReview({
    required this.nickname,
    required this.nicknameTag,
    required this.rating,
    required this.createdAt,
    this.avatarUrl,
    this.comment,
    this.isMine = false,
    this.photoUrls = const [],
  });

  final String nickname;
  final String nicknameTag;
  final String? avatarUrl;
  final int rating;
  final String? comment;
  final DateTime createdAt;
  final bool isMine;
  final List<String> photoUrls;
}

enum ProductReviewSort {
  recent('최신순'),
  rating('별점 높은 순');

  const ProductReviewSort(this.label);
  final String label;
}

class ProductReviewPage {
  const ProductReviewPage({required this.reviews, required this.total});

  final List<ProductReview> reviews;

  /// 이 상품의 리뷰 전체 개수
  final int total;
}

/// 내 리뷰와 리뷰 자격 (배송이 끝난 주문이 있어야 쓴다)
class MyProductReview {
  const MyProductReview({
    required this.canReview,
    this.rating,
    this.comment,
    this.photos = const [],
  });

  final bool canReview;

  /// 아직 쓰지 않았으면 null
  final int? rating;
  final String? comment;
  final List<PhotoItem> photos;

  bool get exists => rating != null;
}

/// 129000 → "129,000원"
String formatPrice(int won) {
  final digits = won.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return '$buffer원';
}

/// 목적격 조사를 붙인다: 받침이 있으면 "을", 없으면 "를". 예: 사이즈를, 색상을
String withObjectParticle(String word) {
  if (word.isEmpty) return word;
  final last = word.codeUnitAt(word.length - 1);
  final isHangul = last >= 0xAC00 && last <= 0xD7A3;
  final hasFinal = isHangul && (last - 0xAC00) % 28 != 0;
  return '$word${hasFinal ? '을' : '를'}';
}

/// 쇼핑 화면 맨 위 광고 칸의 최대 개수
const shopAdSlots = 2;

/// 쇼핑 화면 배치: 맨 위 광고 칸과 그 아래 일반 목록.
/// - [category]가 null이면 전체, 아니면 그 분류 상품만.
/// - 광고 칸에는 지금 보이는 상품 중 광고 상품을 최대 [shopAdSlots]개 넣는다. 광고 상품이 더 많으면
///   [rotation](쇼핑 탭에 들어올 때마다 1씩 늘어난다)만큼 광고 순서를 돌려 번갈아 보여 준다.
/// - 광고 칸에 들어간 상품은 아래 목록에서 빼고, 들어가지 못한 광고 상품은 일반 상품처럼 목록에 둔다.
class ShopLayout {
  const ShopLayout({required this.ads, required this.items});

  factory ShopLayout.of(
    List<Product> products, {
    ProductCategory? category,
    int rotation = 0,
  }) {
    final visible = [
      for (final p in products)
        if (category == null || p.category == category) p,
    ];
    final eligible = [
      for (final p in visible)
        if (p.isAd) p,
    ]..sort((a, b) => a.adRank!.compareTo(b.adRank!));
    final List<Product> ads;
    if (eligible.length <= shopAdSlots) {
      ads = eligible;
    } else {
      final start = rotation % eligible.length;
      ads = [
        for (var i = 0; i < shopAdSlots; i++)
          eligible[(start + i) % eligible.length],
      ];
    }
    final shown = {for (final p in ads) p.id};
    return ShopLayout(
      ads: ads,
      items: [
        for (final p in visible)
          if (!shown.contains(p.id)) p,
      ],
    );
  }

  /// 맨 위 광고 칸 (최대 [shopAdSlots]개)
  final List<Product> ads;

  /// 그 아래 일반 목록 (원래 순서)
  final List<Product> items;
}
