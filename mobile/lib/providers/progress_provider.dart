import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/progress.dart';
import '../repositories/progress_repository.dart';
import 'auth_provider.dart';

final progressRepositoryProvider = Provider<ProgressRepository>((ref) {
  return ProgressRepository(ref.watch(apiServiceProvider));
});

final progressProvider = FutureProvider<Progress>((ref) {
  // Reload when a different account logs in.
  ref.watch(authProvider.select((auth) => auth.value?.id));
  return ref.watch(progressRepositoryProvider).fetchProgress();
});
