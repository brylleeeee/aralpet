import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/admin.dart';
import '../repositories/admin_repository.dart';
import 'auth_provider.dart';

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  return AdminRepository(ref.watch(apiServiceProvider));
});

final adminBadgesProvider = FutureProvider.autoDispose<List<AdminBadge>>((ref) {
  return ref.watch(adminRepositoryProvider).fetchBadges();
});

final adminSettingsProvider = FutureProvider.autoDispose<List<XpRule>>((ref) {
  return ref.watch(adminRepositoryProvider).fetchSettings();
});
