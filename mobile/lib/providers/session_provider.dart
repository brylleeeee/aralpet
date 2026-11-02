import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/session_repository.dart';
import 'auth_provider.dart';

final sessionRepositoryProvider =
    Provider((ref) => SessionRepository(ref.watch(apiServiceProvider)));
