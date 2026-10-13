import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiking_app/app/app.dart';
import 'package:hiking_app/core/database/app_database.dart';
import 'package:hiking_app/core/utils/clock.dart';
import 'package:hiking_app/features/auth/data/auth_repository.dart';
import 'package:hiking_app/features/auth/domain/profile.dart';
import 'package:hiking_app/features/auth/presentation/auth_providers.dart';
import 'package:hiking_app/features/recording/data/location_service.dart';

import '../features/recording/fake_location_service.dart';

/// 테스트용 메모리 DB. 테스트가 끝나면 닫힌다.
AppDatabase testDatabase() {
  final db = AppDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  return db;
}

/// Supabase·GPS 없이 앱 전체를 띄운다.
Future<void> pumpApp(
  WidgetTester tester, {
  required AuthRepository authRepository,
  String nickname = '등산객AB12',
  AppDatabase? database,
  LocationService? location,
  DateTime Function()? clock,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(authRepository),
        myProfileProvider.overrideWith((ref) async {
          final user = ref.watch(currentUserProvider).value;
          return user == null ? null : Profile(id: user.id, nickname: nickname);
        }),
        appDatabaseProvider.overrideWithValue(database ?? testDatabase()),
        locationServiceProvider.overrideWithValue(
          location ?? FakeLocationService(),
        ),
        if (clock != null) clockProvider.overrideWithValue(clock),
      ],
      child: const HikingApp(),
    ),
  );
  await tester.pumpAndSettle();
}
