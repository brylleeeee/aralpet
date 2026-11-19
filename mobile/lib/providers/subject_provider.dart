import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/subject.dart';
import '../repositories/subject_repository.dart';
import 'auth_provider.dart';

final subjectRepositoryProvider = Provider<SubjectRepository>((ref) {
  return SubjectRepository(ref.watch(apiServiceProvider));
});

final subjectsProvider = FutureProvider<List<Subject>>((ref) {
  // Reload when a different account logs in.
  ref.watch(authProvider.select((auth) => auth.value?.id));
  return ref.watch(subjectRepositoryProvider).fetchSubjects();
});
