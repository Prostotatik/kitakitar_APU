import 'package:flutter/material.dart';

/// One accepted material for a center (registration and Firestore).
class CenterMaterialEntry {
  CenterMaterialEntry({
    required this.type,
    required this.label,
    required this.minWeightKg,
    required this.maxWeightKg,
    required this.pricePerKg,
  });

  final String type;
  final String label;
  final double minWeightKg;
  final double maxWeightKg;
  /// Fee per kg. 0 = free.
  final double pricePerKg;

  bool get isFree => pricePerKg <= 0;

  Map<String, dynamic> toFirestore() => {
        'type': type,
        'minWeight': minWeightKg,
        'maxWeight': maxWeightKg,
        'pricePerKg': pricePerKg,
        'isFree': isFree,
      };
}

/// Material types (idea.md) with icons for UI.
const List<Map<String, String>> kMaterialTypes = [
  {'type': 'paper', 'label': 'Paper / Cardboard'},
  {'type': 'plastic', 'label': 'Plastics'},
  {'type': 'glass', 'label': 'Glass'},
  {'type': 'aluminum', 'label': 'Aluminum'},
  {'type': 'batteries', 'label': 'Batteries'},
  {'type': 'electronics', 'label': 'Electronics'},
  {'type': 'food', 'label': 'Food'},
  {'type': 'lawn', 'label': 'Lawn Materials'},
  {'type': 'used_oil', 'label': 'Used Oil'},
  {'type': 'hazardous_waste', 'label': 'Household Hazardous Waste'},
  {'type': 'tires', 'label': 'Tires'},
  {'type': 'metal', 'label': 'Metal'},
];

/// Returns an icon for the given material type.
IconData getMaterialIcon(String type) {
  switch (type) {
    case 'paper':
      return Icons.description_outlined;
    case 'plastic':
      return Icons.local_drink_outlined;
    case 'glass':
      return Icons.wine_bar_outlined;
    case 'aluminum':
      return Icons.kitchen_outlined;
    case 'batteries':
      return Icons.battery_charging_full_outlined;
    case 'electronics':
      return Icons.devices_outlined;
    case 'food':
      return Icons.restaurant_outlined;
    case 'lawn':
      return Icons.grass_outlined;
    case 'used_oil':
      return Icons.water_drop_outlined;
    case 'hazardous_waste':
      return Icons.warning_amber_outlined;
    case 'tires':
      return Icons.directions_car_outlined;
    case 'metal':
      return Icons.build_outlined;
    default:
      return Icons.recycling_outlined;
  }
}
