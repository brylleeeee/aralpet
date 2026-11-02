import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/progress.dart';
import '../repositories/progress_repository.dart';
import 'auth_provider.dart';

final progressRepositoryProvider =
    Provider((ref) => ProgressRepository(ref.watch(apiServiceProvider)));

final progressProvider = FutureProvider<Progress>((ref) {
  return ref.watch(progressRepositoryProvider).fetchProgress();
});
