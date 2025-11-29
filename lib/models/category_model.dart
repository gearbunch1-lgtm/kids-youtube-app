import 'package:flutter/material.dart';

class Category {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final Color color;

  Category({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Category && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

// Predefined kid-friendly categories
final List<Category> kidsCategories = [
  Category(
    id: 'educational',
    name: 'Educational',
    description: 'Science, Math, History',
    icon: Icons.school,
    color: const Color(0xFF6366F1), // Indigo
  ),
  Category(
    id: 'stories',
    name: 'Stories & Tales',
    description: 'Fairy tales, bedtime stories',
    icon: Icons.menu_book,
    color: const Color(0xFFEC4899), // Pink
  ),
  Category(
    id: 'arts',
    name: 'Arts & Crafts',
    description: 'Drawing, DIY projects',
    icon: Icons.palette,
    color: const Color(0xFFF59E0B), // Amber
  ),
  Category(
    id: 'music',
    name: 'Music & Songs',
    description: 'Kids songs, nursery rhymes',
    icon: Icons.music_note,
    color: const Color(0xFF8B5CF6), // Purple
  ),
  Category(
    id: 'animals',
    name: 'Animals & Nature',
    description: 'Wildlife, pets, environment',
    icon: Icons.pets,
    color: const Color(0xFF10B981), // Green
  ),
  Category(
    id: 'games',
    name: 'Fun & Games',
    description: 'Puzzles, brain teasers',
    icon: Icons.sports_esports,
    color: const Color(0xFFEF4444), // Red
  ),
  Category(
    id: 'cartoons',
    name: 'Cartoons',
    description: 'Educational cartoons',
    icon: Icons.tv,
    color: const Color(0xFF3B82F6), // Blue
  ),
  Category(
    id: 'sports',
    name: 'Sports & Activities',
    description: 'Kids sports, exercises',
    icon: Icons.sports_soccer,
    color: const Color(0xFF14B8A6), // Teal
  ),
];
