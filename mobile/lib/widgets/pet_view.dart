
import 'package:flutter/material.dart';

import '../core/theme.dart';

class PetView extends StatelessWidget {
  const PetView({
    super.key,
    required this.stage,
    required this.mood,
    this.size = 96,
    this.showMood = true,
  });

  final String stage;
  final String mood;
  final double size;
  final bool showMood;

  // Pet artwork based on growth stage
  static const Map<String, String> _stageAssets = {
    'egg': 'assets/pets/pet_egg.png',
    'baby': 'assets/pets/pet_baby.png',
    'teen': 'assets/pets/pet_teen.png',
    'adult': 'assets/pets/pet_adult.png',
  };

  static const Map<String, String> _moodLabels = {
    'happy': 'Happy',
    'okay': 'Okay',
    'sad': 'Needs attention',
  };

  @override
  Widget build(BuildContext context) {
    final currentStage = stage.trim().toLowerCase();
    final currentMood = mood.trim().toLowerCase();

    final imagePath =
        _stageAssets[currentStage] ?? _stageAssets['egg']!;

    final moodText = _moodLabels[currentMood] ?? mood;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Purple Galaxy Pet Artwork
        SizedBox(
          width: size * 1.3,
          height: size * 1.3,
          child: Image.asset(
            imagePath,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            errorBuilder: (context, error, stackTrace) {
              return Center(
                child: Icon(
                  Icons.pets_rounded,
                  color: GalaxyColors.purple,
                  size: size * 0.75,
                ),
              );
            },
          ),
        ),

        // Pet mood
        if (showMood) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.favorite_rounded,
                color: GalaxyColors.pink,
                size: 17,
              ),
              const SizedBox(width: 6),
              Text(
                moodText,
                style: const TextStyle(
                  color: GalaxyColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
