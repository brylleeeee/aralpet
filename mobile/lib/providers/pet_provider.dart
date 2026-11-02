import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/pet.dart';
import '../repositories/pet_repository.dart';
import 'auth_provider.dart';

final petRepositoryProvider =
    Provider((ref) => PetRepository(ref.watch(apiServiceProvider)));

final petProvider = FutureProvider<PetInfo>((ref) {
  return ref.watch(petRepositoryProvider).fetchPet();
});
