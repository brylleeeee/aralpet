
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

  // Matches Laravel PetEvolutionService.
  //
  // Existing artwork is reused for the matching stages.
  // Elder temporarily uses adult artwork with a golden
  // crown until a dedicated Elder image is available.
  static const Map<String, String> _stageAssets = {
    'egg': 'assets/pets/pet_egg.png',
    'hatchling': 'assets/pets/pet_baby.png',
    'junior': 'assets/pets/pet_teen.png',
    'adult': 'assets/pets/pet_adult.png',
    'elder': 'assets/pets/pet_adult.png',

    // Backward compatibility with old stage names.
    'baby': 'assets/pets/pet_baby.png',
    'teen': 'assets/pets/pet_teen.png',
  };

  static const Map<String, String> _moodLabels = {
    'happy': 'Happy',
    'okay': 'Okay',
    'sad': 'Needs attention',
  };

  static const Map<String, Color> _stageColors = {
    'egg': GalaxyColors.purple,
    'hatchling': GalaxyColors.blue,
    'junior': GalaxyColors.pink,
    'adult': GalaxyColors.mint,
    'elder': GalaxyColors.gold,
  };

  @override
  Widget build(BuildContext context) {
    final currentStage = stage.trim().toLowerCase();
    final currentMood = mood.trim().toLowerCase();

    final imagePath =
        _stageAssets[currentStage] ??
        _stageAssets['egg']!;

    final moodText =
        _moodLabels[currentMood] ?? mood;

    final stageColor =
        _stageColors[currentStage] ??
        GalaxyColors.purple;

    final isElder = currentStage == 'elder';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Pet artwork with stage-specific effects.
        SizedBox(
          width: size * 1.3,
          height: size * 1.3,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Background glow based on pet stage.
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        stageColor.withValues(
                          alpha: isElder ? 0.24 : 0.12,
                        ),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              // Purple Galaxy Pet Artwork.
              Positioned.fill(
                child: Image.asset(
                  imagePath,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                  errorBuilder: (
                    context,
                    error,
                    stackTrace,
                  ) {
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

              // Elder evolution effect.
              // Distinguishes Elder from Adult while
              // they share the same image asset.
              if (isElder)
                Positioned(
                  top: 0,
                  right: size * 0.03,
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: GalaxyColors.surface
                          .withValues(alpha: 0.9),
                      border: Border.all(
                        color: GalaxyColors.gold
                            .withValues(alpha: 0.8),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: GalaxyColors.gold
                              .withValues(alpha: 0.28),
                          blurRadius: 14,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.workspace_premium_rounded,
                      color: GalaxyColors.gold,
                      size: size * 0.23,
                    ),
                  ),
                ),
            ],
          ),
        ),

        // Pet mood.
        if (showMood) ...[
          const SizedBox(height: 8),

          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
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
