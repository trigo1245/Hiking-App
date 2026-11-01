import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/photos/photo_item.dart';
import '../../../core/supabase/supabase_setup.dart';
import '../../courses/data/review_remote.dart' show reviewPhotoBucket;
import '../domain/shop.dart';

/// 쇼핑을 서버와 주고받는 창구. 주문 자격(배송지)·리뷰 자격(배송 완료)은 서버 함수가 검사한다.
abstract interface class ShopRemote {
  Future<List<Product>> fetchProducts();

  /// 시연용 결제로 주문을 만든다. 배송지는 서버가 내 개인정보에서 복사한다. 주문 id.
  Future<String> placeOrder(String productId, {String? option, int quantity});

  Future<List<ShopOrder>> fetchMyOrders();

  Future<ProductReviewPage> fetchReviews(
    String productId, {
    ProductReviewSort sort,
    int offset,
    int limit,
  });

  Future<MyProductReview> fetchMyReview(String productId);
  Future<void> saveMyReview(String productId, int rating, String comment);
  Future<void> deleteMyReview(String productId);
  Future<void> addReviewPhoto(String productId, Uint8List jpeg);
  Future<void> deleteReviewPhoto(PhotoItem photo);
}

class SupabaseShopRemote implements ShopRemote {
  SupabaseShopRemote(this._client);

  final SupabaseClient _client;

  Future<List<Map<String, dynamic>>> _rows(
    String fn, [
    Map<String, dynamic>? params,
  ]) async {
    final rows = await _client.rpc<List<dynamic>>(fn, params: params);
    return rows.cast<Map<String, dynamic>>();
  }

  String _photoUrl(String path) =>
      _client.storage.from(reviewPhotoBucket).getPublicUrl(path);

  @override
  Future<List<Product>> fetchProducts() async => [
    for (final r in await _rows('get_products'))
      Product(
        id: r['id'] as String,
        category: ProductCategory.parse(r['category'] as String?),
        name: r['name'] as String,
        description: r['description'] as String,
        price: r['price'] as int,
        optionName: r['option_name'] as String?,
        options: [...?(r['options'] as List<dynamic>?)?.cast<String>()],
        art: (r['art'] as int?) ?? 0,
        ratingAvg: (r['rating_avg'] as num?)?.toDouble(),
        reviewCount: (r['review_count'] as int?) ?? 0,
      ),
  ];

  @override
  Future<String> placeOrder(
    String productId, {
    String? option,
    int quantity = 1,
  }) async => await _client.rpc<String>(
    'place_order',
    params: {
      'p_product_id': productId,
      'p_option': option,
      'p_quantity': quantity,
    },
  );

  @override
  Future<List<ShopOrder>> fetchMyOrders() async => [
    for (final r in await _rows('get_my_orders'))
      ShopOrder(
        id: r['id'] as String,
        productId: r['product_id'] as String,
        productName: r['product_name'] as String,
        category: ProductCategory.parse(r['category'] as String?),
        art: (r['art'] as int?) ?? 0,
        optionName: r['option_name'] as String?,
        optionValue: r['option_value'] as String?,
        quantity: r['quantity'] as int,
        totalPrice: r['total_price'] as int,
        recipientName: r['recipient_name'] as String,
        recipientPhone: r['recipient_phone'] as String,
        postcode: r['postcode'] as String?,
        address: r['address'] as String,
        addressDetail: r['address_detail'] as String?,
        createdAt: DateTime.parse(r['created_at'] as String).toLocal(),
        status: OrderStatus.parse(r['status'] as String?),
        hasReview: (r['has_review'] as bool?) ?? false,
      ),
  ];

  @override
  Future<ProductReviewPage> fetchReviews(
    String productId, {
    ProductReviewSort sort = ProductReviewSort.recent,
    int offset = 0,
    int limit = 30,
  }) async {
    final rows = await _rows('get_product_reviews', {
      'p_product_id': productId,
      'p_sort': sort.name,
      'p_offset': offset,
      'p_limit': limit,
    });
    return ProductReviewPage(
      total: rows.isEmpty ? 0 : rows.first['total_count'] as int,
      reviews: [
        for (final r in rows)
          ProductReview(
            nickname: r['nickname'] as String,
            nicknameTag: r['nickname_tag'] as String,
            avatarUrl: r['avatar_url'] as String?,
            rating: r['rating'] as int,
            comment: r['comment'] as String?,
            createdAt: DateTime.parse(r['created_at'] as String).toLocal(),
            isMine: r['is_mine'] as bool,
            photoUrls: [
              for (final p
                  in (r['photo_paths'] as List<dynamic>?)?.cast<String>() ??
                      const <String>[])
                _photoUrl(p),
            ],
          ),
      ],
    );
  }

  @override
  Future<MyProductReview> fetchMyReview(String productId) async {
    final rows = await _rows('get_my_product_review', {
      'p_product_id': productId,
    });
    final r = rows.isEmpty ? const <String, dynamic>{} : rows.first;
    final rating = r['rating'] as int?;
    final userId = _client.auth.currentUser?.id;
    final photos = rating == null || userId == null
        ? const <Map<String, dynamic>>[]
        : await _client
              .from('product_review_photos')
              .select('id, path')
              .eq('product_id', productId)
              .eq('user_id', userId)
              .order('created_at');
    return MyProductReview(
      canReview: (r['can_review'] as bool?) ?? false,
      rating: rating,
      comment: r['comment'] as String?,
      photos: [
        for (final p in photos)
          PhotoItem(
            id: p['id'] as String,
            path: p['path'] as String,
            url: _photoUrl(p['path'] as String),
          ),
      ],
    );
  }

  @override
  Future<void> saveMyReview(String productId, int rating, String comment) =>
      _client.rpc<void>(
        'upsert_my_product_review',
        params: {
          'p_product_id': productId,
          'p_rating': rating,
          'p_comment': comment,
        },
      );

  @override
  Future<void> deleteMyReview(String productId) async {
    // 사진 행은 리뷰와 함께 지워지고, 서버가 그 파일 경로를 돌려준다.
    final paths = await _client.rpc<List<dynamic>>(
      'delete_my_product_review',
      params: {'p_product_id': productId},
    );
    if (paths.isEmpty) return;
    try {
      await _client.storage
          .from(reviewPhotoBucket)
          .remove(paths.cast<String>());
    } catch (e) {
      debugPrint('[photo] 상품 리뷰 사진 파일을 지우지 못했어요: $e');
    }
  }

  @override
  Future<void> addReviewPhoto(String productId, Uint8List jpeg) async {
    final userId = _client.auth.currentUser!.id;
    final id = const Uuid().v4();
    final path = '$userId/product-$productId/$id.jpg';
    await _client.storage
        .from(reviewPhotoBucket)
        .uploadBinary(
          path,
          jpeg,
          fileOptions: const FileOptions(contentType: 'image/jpeg'),
        );
    try {
      await _client.from('product_review_photos').insert({
        'id': id,
        'product_id': productId,
        'user_id': userId,
        'path': path,
      });
    } catch (_) {
      await _client.storage.from(reviewPhotoBucket).remove([path]);
      rethrow;
    }
  }

  @override
  Future<void> deleteReviewPhoto(PhotoItem photo) async {
    await _client.from('product_review_photos').delete().eq('id', photo.id);
    try {
      await _client.storage.from(reviewPhotoBucket).remove([photo.path]);
    } catch (e) {
      debugPrint('[photo] 파일을 지우지 못했어요: $e');
    }
  }
}

final shopRemoteProvider = Provider<ShopRemote>((ref) {
  return SupabaseShopRemote(ref.watch(supabaseClientProvider));
});

// 화면에서 쓰는 값. 실패하면 자동으로 다시 시도하지 않고 오류를 보여 준다.
final productsProvider = FutureProvider.autoDispose<List<Product>>(
  (ref) => ref.watch(shopRemoteProvider).fetchProducts(),
  retry: (_, _) => null,
);

/// 상품 하나 (목록에서 찾는다. 상품은 12개뿐이라 목록을 함께 쓴다)
final productProvider = FutureProvider.autoDispose.family<Product?, String>((
  ref,
  id,
) async {
  final products = await ref.watch(productsProvider.future);
  return products.where((p) => p.id == id).firstOrNull;
}, retry: (_, _) => null);

final myOrdersProvider = FutureProvider.autoDispose<List<ShopOrder>>(
  (ref) => ref.watch(shopRemoteProvider).fetchMyOrders(),
  retry: (_, _) => null,
);

/// (상품 id, 정렬) → 리뷰 첫 30개
final productReviewsProvider = FutureProvider.autoDispose
    .family<ProductReviewPage, (String, ProductReviewSort)>(
      (ref, key) =>
          ref.watch(shopRemoteProvider).fetchReviews(key.$1, sort: key.$2),
      retry: (_, _) => null,
    );

final myProductReviewProvider = FutureProvider.autoDispose
    .family<MyProductReview, String>(
      (ref, id) => ref.watch(shopRemoteProvider).fetchMyReview(id),
      retry: (_, _) => null,
    );
