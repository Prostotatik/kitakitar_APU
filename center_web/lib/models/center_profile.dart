/// Center document from Firestore (/centers/{centerId}).
class CenterProfile {
  CenterProfile({
    required this.name,
    required this.address,
    required this.lat,
    required this.lng,
    required this.managerName,
    required this.managerPhone,
    required this.managerEmail,
    required this.points,
    required this.totalWeight,
    this.createdAt,
    this.isActive = true,
  });

  final String name;
  final String address;
  final double lat;
  final double lng;
  final String managerName;
  final String managerPhone;
  final String managerEmail;
  final int points;
  final double totalWeight;
  final DateTime? createdAt;
  final bool isActive;

  static CenterProfile? fromFirestore(Map<String, dynamic>? data) {
    if (data == null) return null;
    final loc = data['location'] as Map<String, dynamic>?;
    final lat = (loc?['lat'] as num?)?.toDouble();
    final lng = (loc?['lng'] as num?)?.toDouble();
    final manager = data['manager'] as Map<String, dynamic>? ?? {};
    if (lat == null || lng == null) return null;
    return CenterProfile(
      name: data['name'] as String? ?? '',
      address: data['address'] as String? ?? '',
      lat: lat,
      lng: lng,
      managerName: manager['name'] as String? ?? '',
      managerPhone: manager['phone'] as String? ?? '',
      managerEmail: manager['email'] as String? ?? '',
      points: (data['points'] as num?)?.toInt() ?? 0,
      totalWeight: (data['totalWeight'] as num?)?.toDouble() ?? 0.0,
      createdAt: (data['createdAt'] as dynamic)?.toDate() as DateTime?,
      isActive: data['isActive'] as bool? ?? true,
    );
  }
}
