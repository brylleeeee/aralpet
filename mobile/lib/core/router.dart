import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/auth/splash_screen.dart';
import '../screens/main_shell.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/tasks/tasks_screen.dart';
import '../screens/focus/focus_screen.dart';
import '../screens/pet/pet_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  // Re-checks the redirect whenever the login state changes.
  final authState = ValueNotifier<AsyncValue<User?>>(const AsyncLoading());
  ref.listen(authProvider, (_, next) => authState.value = next,
      fireImmediately: true);
  ref.onDispose(authState.dispose);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: authState,
    redirect: (context, state) {
      final auth = authState.value;
      final location = state.matchedLocation;
      final onSplash = location == '/splash';
      final onAuthPage = location == '/login' || location == '/register';

      // Still checking the saved token: stay on the splash screen.
      if (!auth.hasValue) return onSplash ? null : '/splash';

      final loggedIn = auth.requireValue != null;
      if (!loggedIn) return onAuthPage ? null : '/login';
      if (onSplash || onAuthPage) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/register', builder: (context, state) => const RegisterScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MainShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/home', builder: (context, state) => const DashboardScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/tasks', builder: (context, state) => const TasksScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/focus', builder: (context, state) => const FocusScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/pet', builder: (context, state) => const PetScreen()),
          ]),
        ],
      ),
    ],
  );
});