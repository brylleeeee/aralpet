import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/badge.dart';
import '../models/pet_info.dart';
import '../models/weekly_summary.dart';
import '../repositories/pet_repository.dart';
import 'auth_provider.dart';

final petRepositoryProvider = Provider<PetRepository>((ref) {
  return PetRepository(ref.watch(apiServiceProvider));
});

final petProvider = FutureProvider<PetInfo>((ref) {
  ref.watch(authProvider.select((auth) => auth.value?.id));
  return ref.watch(petRepositoryProvider).fetchPet();
});

final badgesProvider = FutureProvider<List<StudyBadge>>((ref) {
  ref.watch(authProvider.select((auth) => auth.value?.id));
  return ref.watch(petRepositoryProvider).fetchBadges();
});

/// Weekly summary for the week that contains the given day.
final weeklySummaryProvider =
    FutureProvider.family<WeeklySummary, DateTime>((ref, weekOf) {
  ref.watch(authProvider.select((auth) => auth.value?.id));
  return ref.watch(petRepositoryProvider).fetchWeeklySummary(weekOf);
});

/// Call after anything that can earn XP, so every screen shows fresh numbers.
void refreshRewards(WidgetRef ref) {
  ref.invalidate(petProvider);
  ref.invalidate(badgesProvider);
  ref.invalidate(weeklySummaryProvider);
}
