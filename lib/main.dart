import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';

void main() {
  // ProviderScope: Riverpod의 상태(provider)들이 저장되는 최상위 공간.
  runApp(const ProviderScope(child: HikingApp()));
}
