import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router.dart';
import 'theme.dart';

class HikingApp extends ConsumerWidget {
  const HikingApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: '등산 기록',
      debugShowCheckedModeBanner: false,
      theme: buildLightTheme(),
      routerConfig: router,
    );
  }
}
