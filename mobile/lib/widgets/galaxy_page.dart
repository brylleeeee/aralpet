import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme.dart';

/// Header for pages opened on top of the tabs (Badges, Summary, Profile).
class GalaxyPageHeader extends StatelessWidget {
  const GalaxyPageHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.iconColor = GalaxyColors.purple,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          tooltip: 'Back',
          onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
          icon: const Icon(Icons.arrow_back_rounded, color: GalaxyColors.textPrimary),
        ),
        const SizedBox(width: 4),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: iconColor, size: 25),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: GalaxyColors.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(color: GalaxyColors.textSecondary, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Rounded card used on the new pages.
class GalaxyCard extends StatelessWidget {
  const GalaxyCard({super.key, required this.child, this.padding = const EdgeInsets.all(16)});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: GalaxyColors.surface.withValues(alpha: 0.91),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: GalaxyColors.purple.withValues(alpha: 0.26)),
      ),
      child: child,
    );
  }
}

/// Error message with a retry button.
class GalaxyError extends StatelessWidget {
  const GalaxyError({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 12),
      child: Column(
        children: [
          const Icon(Icons.cloud_off_rounded, color: GalaxyColors.purple, size: 48),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: GalaxyColors.textSecondary),
          ),
          const SizedBox(height: 14),
          FilledButton(onPressed: onRetry, child: const Text('Try Again')),
        ],
      ),
    );
  }
}

const galaxyLoading = Padding(
  padding: EdgeInsets.symmetric(vertical: 50),
  child: Center(child: CircularProgressIndicator(color: GalaxyColors.purple)),
);
