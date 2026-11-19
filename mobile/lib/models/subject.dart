import 'package:flutter/material.dart';

class Subject {
  final int id;
  final String name;
  final String color; // hex, e.g. #4F46E5
  final int tasksCount;

  const Subject({
    required this.id,
    required this.name,
    required this.color,
    this.tasksCount = 0,
  });

  Color get colorValue => hexToColor(color);

  factory Subject.fromJson(Map<String, dynamic> json) => Subject(
        id: (json['id'] as num).toInt(),
        name: json['name']?.toString() ?? '',
        color: json['color']?.toString() ?? '#A78BFA',
        tasksCount: (json['tasks_count'] as num?)?.toInt() ?? 0,
      );
}

/// "#4F46E5" -> Color. Falls back to purple if the text is not a hex color.
Color hexToColor(String? hex) {
  final value = int.tryParse((hex ?? '').replaceFirst('#', ''), radix: 16);
  if (value == null || (hex ?? '').length != 7) return const Color(0xFFA78BFA);
  return Color(0xFF000000 | value);
}

/// Colors a student can pick for a subject (they read well on the dark theme).
const subjectColors = [
  '#A78BFA', // purple
  '#38BDF8', // blue
  '#34D399', // mint
  '#FBBF24', // gold
  '#F472B6', // pink
  '#FB923C', // orange
  '#F87171', // red
  '#2DD4BF', // teal
];
