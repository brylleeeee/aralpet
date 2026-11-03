
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme.dart';

class MainShell extends StatelessWidget {
  const MainShell({
    super.key,
    required this.navigationShell,
  });

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      body: navigationShell,

      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 7,
            ),
            decoration: BoxDecoration(
              color: GalaxyColors.surface.withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: GalaxyColors.purple.withValues(alpha: 0.30),
              ),
              boxShadow: [
                BoxShadow(
                  color: GalaxyColors.purple.withValues(alpha: 0.15),
                  blurRadius: 25,
                  spreadRadius: 1,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: Row(
              children: [
                _buildNavItem(
                  index: 0,
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home_rounded,
                  label: 'Home',
                  glowColor: GalaxyColors.purple,
                ),
                _buildNavItem(
                  index: 1,
                  icon: Icons.check_circle_outline_rounded,
                  activeIcon: Icons.check_circle_rounded,
                  label: 'Tasks',
                  glowColor: GalaxyColors.blue,
                ),
                _buildNavItem(
                  index: 2,
                  icon: Icons.timer_outlined,
                  activeIcon: Icons.timer_rounded,
                  label: 'Focus',
                  glowColor: GalaxyColors.gold,
                ),
                _buildNavItem(
                  index: 3,
                  icon: Icons.pets_outlined,
                  activeIcon: Icons.pets_rounded,
                  label: 'My Pet',
                  glowColor: GalaxyColors.pink,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required Color glowColor,
  }) {
    final isSelected = navigationShell.currentIndex == index;

    return Expanded(
      child: _AnimatedGalaxyNavItem(
        icon: icon,
        activeIcon: activeIcon,
        label: label,
        glowColor: glowColor,
        isSelected: isSelected,
        onTap: () {
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
        },
      ),
    );
  }
}

class _AnimatedGalaxyNavItem extends StatefulWidget {
  const _AnimatedGalaxyNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.glowColor,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final Color glowColor;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  State<_AnimatedGalaxyNavItem> createState() =>
      _AnimatedGalaxyNavItemState();
}

class _AnimatedGalaxyNavItemState
    extends State<_AnimatedGalaxyNavItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bounceController;
  late final Animation<double> _bounceAnimation;

  @override
  void initState() {
    super.initState();

    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 430),
    );

    // Icon moves upward and returns to its normal position.
    _bounceAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).chain(
          CurveTween(curve: Curves.easeOutCubic),
        ),
        weight: 45,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: 0.0,
        ).chain(
          CurveTween(curve: Curves.easeOutBack),
        ),
        weight: 55,
      ),
    ]).animate(_bounceController);
  }

  @override
  void didUpdateWidget(
    covariant _AnimatedGalaxyNavItem oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);

    // Bounce when this tab becomes selected.
    if (!oldWidget.isSelected && widget.isSelected) {
      if (!MediaQuery.disableAnimationsOf(context)) {
        _bounceController.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _bounceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    final duration = reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 260);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(17),
        splashColor: widget.glowColor.withValues(alpha: 0.20),
        highlightColor: widget.glowColor.withValues(alpha: 0.10),
        child: AnimatedContainer(
          duration: duration,
          curve: Curves.easeInOutCubic,
          padding: const EdgeInsets.symmetric(
            horizontal: 3,
            vertical: 9,
          ),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? widget.glowColor.withValues(alpha: 0.16)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(17),
            border: Border.all(
              color: widget.isSelected
                  ? widget.glowColor.withValues(alpha: 0.45)
                  : Colors.transparent,
            ),
            boxShadow: widget.isSelected
                ? [
                    BoxShadow(
                      color: widget.glowColor.withValues(alpha: 0.20),
                      blurRadius: 15,
                      spreadRadius: 1,
                    ),
                  ]
                : [],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Animated icon
              AnimatedBuilder(
                animation: _bounceAnimation,
                builder: (context, child) {
                  final bounce = reduceMotion
                      ? 0.0
                      : _bounceAnimation.value;

                  return Transform.translate(
                    offset: Offset(0, -5 * bounce),
                    child: Transform.scale(
                      scale: 1.0 + (0.14 * bounce),
                      child: child,
                    ),
                  );
                },
                child: AnimatedSwitcher(
                  duration: duration,
                  switchInCurve: Curves.easeOutBack,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: ScaleTransition(
                        scale: animation,
                        child: child,
                      ),
                    );
                  },
                  child: Icon(
                    widget.isSelected
                        ? widget.activeIcon
                        : widget.icon,
                    key: ValueKey(widget.isSelected),
                    size: 24,
                    color: widget.isSelected
                        ? widget.glowColor
                        : GalaxyColors.textSecondary,
                  ),
                ),
              ),

              const SizedBox(height: 5),

              // Animated tab label
              AnimatedDefaultTextStyle(
                duration: duration,
                curve: Curves.easeInOut,
                style: TextStyle(
                  color: widget.isSelected
                      ? GalaxyColors.textPrimary
                      : GalaxyColors.textSecondary,
                  fontSize: 11,
                  fontWeight: widget.isSelected
                      ? FontWeight.w800
                      : FontWeight.w500,
                ),
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: 5),

              // Small glowing indicator underneath the active tab
              AnimatedContainer(
                duration: duration,
                curve: Curves.easeInOut,
                height: 3,
                width: widget.isSelected ? 20 : 0,
                decoration: BoxDecoration(
                  color: widget.glowColor,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: widget.isSelected
                      ? [
                          BoxShadow(
                            color: widget.glowColor.withValues(
                              alpha: 0.65,
                            ),
                            blurRadius: 8,
                          ),
                        ]
                      : [],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
