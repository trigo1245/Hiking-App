/// 사진을 올리기 전에 줄이는 기준과 장수 제한 (CLAUDE.md 6-2장 "사진")
class PhotoSpec {
  const PhotoSpec({
    required this.maxLongSide,
    required this.quality,
    required this.maxCount,
  });

  /// 긴 변의 최대 픽셀
  final int maxLongSide;

  /// JPEG 품질 (0~100)
  final int quality;

  /// 한 곳에 붙일 수 있는 최대 장수
  final int maxCount;

  /// 산행 기록: 본인만 보지만 크게 넘겨 보므로 1600px. 한 장 약 0.2~0.4MB.
  static const activity = PhotoSpec(
    maxLongSide: 1600,
    quality: 80,
    maxCount: 10,
  );

  /// 리뷰: 여러 사람이 보므로 전송량을 줄여 1280px.
  static const review = PhotoSpec(maxLongSide: 1280, quality: 80, maxCount: 3);

  /// 프로필 사진: 작은 동그라미로만 보이므로 512px.
  static const avatar = PhotoSpec(maxLongSide: 512, quality: 85, maxCount: 1);

  /// 이미 [existing]장이 있을 때 더 붙일 수 있는 장수
  int remaining(int existing) => (maxCount - existing).clamp(0, maxCount);
}
