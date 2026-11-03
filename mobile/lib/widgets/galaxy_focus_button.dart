
import 'package:flutter/material.dart';

import '../core/theme.dart';

class GalaxyFocusButton extends StatefulWidget {
  const GalaxyFocusButton({
    super.key,
    required this.onPressed,
  });

  final VoidCallback onPressed;

  @override
  State<GalaxyFocusButton> createState() =>
      _GalaxyFocusButtonState();
}

class _GalaxyFocusButtonState extends State<GalaxyFocusButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _glowAnimation;

  bool _isPressed = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _glowAnimation = Tween<double>(
      begin: 0.15,
      end: 0.55,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    if (reduceMotion) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return AnimatedScale(
          scale: reduceMotion ? 1.0 : (_isPressed ? 0.96 : 1.0),
          duration: reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 130),
          curve: Curves.easeOut,
          child: Container(
            height: 59,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF7041D4),
                  Color(0xFFA77BFF),
                  Color(0xFF7846DD),
                ],
              ),
              borderRadius: BorderRadius.circular(19),
              border: Border.all(
                color: const Color(0xFFD9BDFF),
                width: 1.3,
              ),
              boxShadow: [
                BoxShadow(
                  color: GalaxyColors.purple.withValues(
                    alpha: reduceMotion
                        ? 0.25
                        : _glowAnimation.value,
                  ),
                  blurRadius: reduceMotion
                      ? 15
                      : 16 + (_controller.value * 14),
                  spreadRadius: reduceMotion
                      ? 0
                      : _controller.value * 3,
                ),
              ],
            ),
            child: child,
          ),
        );
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(19),
          onTapDown: (_) {
            if (mounted) {
              setState(() => _isPressed = true);
            }
          },
          onTapUp: (_) {
            if (mounted) {
              setState(() => _isPressed = false);
            }
          },
          onTapCancel: () {
            if (mounted) {
              setState(() => _isPressed = false);
            }
          },
          onTap: widget.onPressed,
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.play_circle_fill_rounded,
                color: Colors.white,
                size: 27,
              ),
              SizedBox(width: 11),
              Text(
                'Start Focus Session',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
              SizedBox(width: 9),
              Icon(
                Icons.auto_awesome_rounded,
                color: GalaxyColors.gold,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
