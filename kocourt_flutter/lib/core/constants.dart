import 'package:flutter/material.dart';
import 'icons.dart';

class SportCategory {
  final String id;
  final String label;
  final IconData icon;
  final String emoji;

  const SportCategory({
    required this.id,
    required this.label,
    required this.icon,
    required this.emoji,
  });
}

const sportCategories = [
  SportCategory(id: 'All', label: 'All', icon: AppIcons.layers, emoji: '🏟️'),
  SportCategory(id: 'turf', label: 'Football', icon: AppIcons.flag, emoji: '⚽'),
  SportCategory(id: 'shuttle', label: 'Badminton', icon: AppIcons.wind, emoji: '🏸'),
  SportCategory(id: 'tennis', label: 'Tennis', icon: AppIcons.activity, emoji: '🎾'),
  SportCategory(id: 'cricket', label: 'Cricket', icon: AppIcons.target, emoji: '🏏'),
  SportCategory(id: 'gym', label: 'Gym', icon: AppIcons.dumbbell, emoji: '🏋️'),
  SportCategory(id: 'swimming', label: 'Swimming', icon: AppIcons.waves, emoji: '🏊'),
  SportCategory(id: 'boxing', label: 'Boxing', icon: AppIcons.swords, emoji: '🥊'),
  SportCategory(id: 'basket', label: 'Basketball', icon: AppIcons.circle, emoji: '🏀'),
];

const venueImages = {
  'shuttle': 'https://images.unsplash.com/photo-1626224583764-f87db24ac4ea?w=600&q=80',
  'turf': 'https://images.unsplash.com/photo-1579952363873-27f3bade9f55?w=600&q=80',
  'gym': 'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?w=600&q=80',
  'cricket': 'https://images.unsplash.com/photo-1540747913346-19212a4b8277?w=600&q=80',
  'tennis': 'https://images.unsplash.com/photo-1554068865-24cecd4e34b8?w=600&q=80',
  'basket': 'https://images.unsplash.com/photo-1546519638-68e109498ffc?w=600&q=80',
  'swimming': 'https://images.unsplash.com/photo-1576013551627-0cc20b96c2a7?w=600&q=80',
  'boxing': 'https://images.unsplash.com/photo-1549719386-74dfcbf7dbed?w=600&q=80',
  'other': 'https://images.unsplash.com/photo-1535131749006-b7f58c99034b?w=600&q=80',
};

String getVenueImage(Map<String, dynamic> venue) {
  return venue['image_url'] ??
      venueImages[venue['type']] ??
      venueImages['other']!;
}
