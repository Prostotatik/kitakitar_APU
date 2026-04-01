import 'package:cloud_firestore/cloud_firestore.dart';

class CenterModel {
  final String id;
  final String name;
  final String address;
  final GeoPoint location;
  final ManagerInfo manager;
  final int points;
  final double totalWeight;
  final DateTime createdAt;
  final bool isActive;

  CenterModel({
    required this.id,
    required this.name,
    required this.address,
    required this.location,
    required this.manager,
    required this.points,
    required this.totalWeight,
    required this.createdAt,
    required this.isActive,
  });

  factory CenterModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    GeoPoint location;
    final loc = data['location'];
    if (loc is GeoPoint) {
      location = loc;
    } else if (loc is Map) {
      final lat = (loc['lat'] as num?)?.toDouble() ?? 0.0;
      final lng = (loc['lng'] as num?)?.toDouble() ?? 0.0;
      location = GeoPoint(lat, lng);
    } else {
      location = const GeoPoint(0, 0);
    }
    return CenterModel(
      id: doc.id,
      name: data['name'] ?? '',
      address: data['address'] ?? '',
      location: location,
      manager: ManagerInfo.fromMap(data['manager'] ?? {}),
      points: data['points'] ?? 0,
      totalWeight: (data['totalWeight'] ?? 0).toDouble(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isActive: data['isActive'] ?? true,
    );
  }
}

class ManagerInfo {
  final String name;
  final String phone;
  final String email;

  ManagerInfo({
    required this.name,
    required this.phone,
    required this.email,
  });

  factory ManagerInfo.fromMap(Map<String, dynamic> map) {
    return ManagerInfo(
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      email: map['email'] ?? '',
    );
  }
}

class CenterMaterial {
  final String id;
  final String type;
  final double minWeight;
  final double maxWeight;
  final double? pricePerKg;
  final bool isFree;

  CenterMaterial({
    required this.id,
    required this.type,
    required this.minWeight,
    required this.maxWeight,
    this.pricePerKg,
    required this.isFree,
  });

  factory CenterMaterial.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CenterMaterial(
      id: doc.id,
      type: data['type'] ?? '',
      minWeight: (data['minWeight'] ?? 0).toDouble(),
      maxWeight: (data['maxWeight'] ?? 0).toDouble(),
      pricePerKg: data['pricePerKg']?.toDouble(),
      isFree: data['isFree'] ?? false,
    );
  }

  bool acceptsMaterial(String materialType, double weight) {
    return type == materialType &&
        weight >= minWeight &&
        weight <= maxWeight;
  }
}

