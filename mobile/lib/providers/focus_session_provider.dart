import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/focus_session_repository.dart';
import 'auth_provider.dart';

final focusSessionRepositoryProvider = Provider<FocusSessionRepository>((ref) {
  return FocusSessionRepository(ref.watch(apiServiceProvider));
});
