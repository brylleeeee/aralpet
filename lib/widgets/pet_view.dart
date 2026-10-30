import 'package:flutter/material.dart';

class PetView extends StatelessWidget {
  const PetView({
    super.key,
    required this.stage,
    required this.mood,
    this.size = 96,
  });

  final String stage;
  final String mood;
  final double size;

  // Placeholder emojis. Replace with real pet images later.
  static const _stageEmoji = {
    'egg': '🥚',
    'baby': '🐣',
    'teen': '🐥',
    'adult': '🐔',
  };

  static const _moodLabel = {
    'happy': 'Happy',
    'okay': 'Okay',
    'sad': 'Needs attention',
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(_stageEmoji[stage] ?? '🥚', style: TextStyle(fontSize: size)),
        const SizedBox(height: 4),
        Text(_moodLabel[mood] ?? mood,
            style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}