// 프로필·개인정보 입력 규칙 (순수 Dart, 단위 테스트 대상). CLAUDE.md 6-2장 "프로필과 개인정보"

/// 프로필 소개 최대 길이
const bioMaxLength = 300;

/// 주 활동 지역 최대 길이 (양식 없이 직접 입력)
const regionMaxLength = 30;

final _nicknamePattern = RegExp(r'^[가-힣A-Za-z0-9]+$');

/// 닉네임이 규칙(2~10자, 한글·영문·숫자)에 맞지 않으면 이유를, 맞으면 null.
/// 서버(update_my_profile)도 같은 규칙으로 다시 검사한다.
String? nicknameError(String input) {
  final v = input.trim();
  if (v.length < 2 || v.length > 10) return '닉네임은 2~10자로 정해 주세요';
  if (!_nicknamePattern.hasMatch(v)) return '한글·영문·숫자만 쓸 수 있어요 (띄어쓰기 안 돼요)';
  return null;
}

/// 휴대폰 번호에서 숫자만 남긴다. 예: 010-1234-5678 → 01012345678
String normalizePhone(String input) => input.replaceAll(RegExp(r'[^0-9]'), '');

/// 휴대폰 번호가 맞지 않으면 이유를, 맞거나 비어 있으면 null.
String? phoneError(String input) {
  final digits = normalizePhone(input);
  if (digits.isEmpty) return null;
  if (!RegExp(r'^01[0-9]{8,9}$').hasMatch(digits)) {
    return '휴대폰 번호를 확인해 주세요 (예: 010-1234-5678)';
  }
  return null;
}

/// 보기 좋게 하이픈을 넣는다. 예: 01012345678 → 010-1234-5678
String formatPhone(String digits) {
  final d = normalizePhone(digits);
  if (d.length == 11) {
    return '${d.substring(0, 3)}-${d.substring(3, 7)}-${d.substring(7)}';
  }
  if (d.length == 10) {
    return '${d.substring(0, 3)}-${d.substring(3, 6)}-${d.substring(6)}';
  }
  return d;
}

/// 개인정보 항목. 기능마다 필요한 항목이 다르다(예: 포토북 배송은 셋 다).
enum PrivateField {
  name('이름'),
  phone('휴대폰 번호'),
  address('주소');

  const PrivateField(this.label);
  final String label;
}

/// 본인만 보는 개인정보. 비어 있어도 되고, 필요한 기능에서만 입력을 받는다.
class PrivateInfo {
  const PrivateInfo({
    this.name,
    this.phone,
    this.postcode,
    this.address,
    this.addressDetail,
  });

  final String? name;

  /// 숫자만. 예: 01012345678
  final String? phone;

  /// 우편번호 5자리
  final String? postcode;

  /// 도로명(또는 지번) 기본 주소
  final String? address;

  /// 동·호수 같은 상세 주소
  final String? addressDetail;

  bool has(PrivateField field) => switch (field) {
    PrivateField.name => (name ?? '').trim().isNotEmpty,
    PrivateField.phone =>
      phoneError(phone ?? '') == null && (phone ?? '').isNotEmpty,
    PrivateField.address =>
      (postcode ?? '').isNotEmpty && (address ?? '').isNotEmpty,
  };

  /// [required] 중 비어 있는 항목 (화면 순서대로)
  List<PrivateField> missing(Set<PrivateField> required) => [
    for (final f in PrivateField.values)
      if (required.contains(f) && !has(f)) f,
  ];

  bool get isEmpty => PrivateField.values.every((f) => !has(f));

  /// 한 줄 요약 (내 정보 화면). 예: "이름·주소 입력함"
  String get summary {
    final filled = [
      for (final f in PrivateField.values)
        if (has(f)) f.label,
    ];
    return filled.isEmpty ? '아직 입력하지 않았어요' : '${filled.join('·')} 입력함';
  }
}

/// 카카오(다음) 우편번호 서비스가 돌려준 값에서 우편번호와 기본 주소를 꺼낸다.
/// 사용자가 고른 쪽(도로명 R / 지번 J)을 쓰고, 도로명이면 건물 이름을 괄호로 붙인다.
({String postcode, String address})? addressFromPostcode(
  Map<String, dynamic> data,
) {
  final postcode = (data['zonecode'] as String?) ?? '';
  final jibun = data['userSelectedType'] == 'J';
  var address =
      ((jibun ? data['jibunAddress'] : data['roadAddress']) as String?) ??
      (data['address'] as String?) ??
      '';
  if (address.isEmpty) address = (data['address'] as String?) ?? '';
  final building = (data['buildingName'] as String?) ?? '';
  if (!jibun && building.isNotEmpty) address = '$address ($building)';
  if (postcode.isEmpty || address.isEmpty) return null;
  return (postcode: postcode, address: address);
}
