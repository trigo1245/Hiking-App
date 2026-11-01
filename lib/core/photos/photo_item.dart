/// 서버에 올라간 사진 한 장. [url]은 화면에 그릴 주소(공개 주소 또는 기간 제한 주소).
class PhotoItem {
  const PhotoItem({required this.id, required this.path, required this.url});

  final String id;

  /// Storage 경로 (지울 때 쓴다)
  final String path;
  final String url;
}
