import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 현재 시각. 테스트에서 시간을 마음대로 정할 수 있도록 provider로 받는다.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);
