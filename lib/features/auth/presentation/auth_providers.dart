import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/env.dart';
import '../../../core/supabase/supabase_setup.dart';
import '../data/auth_repository.dart';
import '../data/profile_repository.dart';
import '../data/supabase_auth_repository.dart';
import '../domain/app_user.dart';
import '../domain/auth_failure.dart';
import '../domain/profile.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return SupabaseAuthRepository(
    auth: ref.watch(supabaseClientProvider).auth,
    redirectUrl: Env.authRedirectUrl,
  );
});

/// 현재 로그인 사용자. 로그인 상태가 바뀔 때마다 새 값이 온다.
final currentUserProvider = StreamProvider<AppUser?>((ref) async* {
  final repository = ref.watch(authRepositoryProvider);
  yield repository.currentUser;
  yield* repository.watchUser();
});

/// 브라우저 로그인(카카오)에서 나중에 도착하는 오류.
final authFailuresProvider = StreamProvider<AuthFailure>((ref) {
  return ref.watch(authRepositoryProvider).watchFailures();
});

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.watch(supabaseClientProvider));
});

/// 내 프로필. 로그인한 사용자가 바뀔 때만 다시 불러온다.
final myProfileProvider = FutureProvider<Profile?>((ref) async {
  final userId = ref.watch(currentUserProvider.select((u) => u.value?.id));
  if (userId == null) return null;
  return ref.watch(profileRepositoryProvider).fetchProfile(userId);
});
