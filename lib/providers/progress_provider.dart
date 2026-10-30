import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/progress.dart';
import '../repositories/progress_repository.dart';

final progressRepositoryProvider = Provider((ref) => ProgressRepository());

final progressProvider = FutureProvider<Progress>((ref) {
  return ref.watch(progressRepositoryProvider).fetchProgress();
});