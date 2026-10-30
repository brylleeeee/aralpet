import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_service.dart';
import '../core/token_storage.dart';
import '../models/user.dart';
import '../repositories/auth_repository.dart';

final tokenStorageProvider = Provider((ref) => TokenStorage());

final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService(
    ref.watch(tokenStorageProvider),
    onUnauthorized: () => ref.read(authProvider.notifier).signedOutByServer(),
  );
});

final authRepositoryProvider = Provider((ref) {
  return AuthRepository(
    ref.watch(apiServiceProvider),
    ref.watch(tokenStorageProvider),
  );
});

/// null = logged out, User = logged in, loading = checking the saved token.
final authProvider =
    AsyncNotifierProvider<AuthNotifier, User?>(AuthNotifier.new);

class AuthNotifier extends AsyncNotifier<User?> {
  AuthRepository get _repo => ref.read(authRepositoryProvider);

  @override
  Future<User?> build() => _repo.restoreSession();

  Future<void> login(String email, String password) async {
    final user = await _repo.login(email, password);
    state = AsyncData(user);
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
  }) async {
    final user = await _repo.register(
      name: name,
      email: email,
      password: password,
      passwordConfirmation: passwordConfirmation,
    );
    state = AsyncData(user);
  }

  Future<void> logout() async {
    await _repo.logout();
    state = const AsyncData(null);
  }

  void signedOutByServer() => state = const AsyncData(null);
}