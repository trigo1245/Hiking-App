import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiking_app/app/app.dart';
import 'package:hiking_app/features/auth/data/auth_repository.dart';
import 'package:hiking_app/features/auth/domain/profile.dart';
import 'package:hiking_app/features/auth/presentation/auth_providers.dart';

/// Supabase 없이 앱 전체를 띄운다.
Future<void> pumpApp(
  WidgetTester tester, {
  required AuthRepository authRepository,
  String nickname = '등산객AB12',
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(authRepository),
        myProfileProvider.overrideWith((ref) async {
          final user = ref.watch(currentUserProvider).value;
          return user == null ? null : Profile(id: user.id, nickname: nickname);
        }),
      ],
      child: const HikingApp(),
    ),
  );
  await tester.pumpAndSettle();
}
