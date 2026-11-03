
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router.dart';
import 'core/theme.dart';
import 'widgets/galaxy_background.dart';

void main() {
  runApp(const ProviderScope(child: AralPetApp()));
}

class AralPetApp extends ConsumerWidget {
  const AralPetApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'AralPet',
      debugShowCheckedModeBanner: false,

      // Dark Gamer Galaxy theme
      theme: AppTheme.dark,
      themeMode: ThemeMode.dark,

      // Display one animated galaxy behind the entire app.
      builder: (context, child) {
        return Stack(
          children: [
            const Positioned.fill(
              child: GalaxyBackground(),
            ),
            if (child != null)
              Positioned.fill(
                child: child,
              ),
          ],
        );
      },

      routerConfig: router,
    );
  }
}
