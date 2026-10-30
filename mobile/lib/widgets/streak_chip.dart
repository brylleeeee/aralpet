import 'package:flutter/material.dart';

class StreakChip extends StatelessWidget {
  const StreakChip({super.key, required this.days});

  final int days;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: const Icon(Icons.local_fire_department, color: Colors.deepOrange),
      label: Text('$days-day streak'),
    );
  }
}