import 'package:flutter/material.dart';

class XpBar extends StatelessWidget {
  const XpBar({
    super.key,
    required this.level,
    required this.current,
    required this.target,
  });

  final int level;
  final int current;
  final int target;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final value = target == 0 ? 0.0 : (current / target).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Level $level',
                style: text.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const Spacer(),
            Text('$current / $target XP', style: text.bodySmall),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(value: value, minHeight: 12),
        ),
      ],
    );
  }
}