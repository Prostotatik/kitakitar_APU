import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String name;
  final String email;
  final String? avatarUrl;
  final int points;
  final double totalWeight;
  final DateTime createdAt;
  final DateTime? lastLoginAt;
  final String provider;
  final Map<String, double> stats; // material type -> weight

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.avatarUrl,
    required this.points,
    required this.totalWeight,
    required this.createdAt,
    this.lastLoginAt,
    required this.provider,
    required this.stats,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      id: doc.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      avatarUrl: data['avatarUrl'],
      points: data['points'] ?? 0,
      totalWeight: (data['totalWeight'] ?? 0).toDouble(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastLoginAt: (data['lastLoginAt'] as Timestamp?)?.toDate(),
      provider: data['provider'] ?? 'email',
      stats: Map<String, double>.from(
        (data['stats'] ?? {}) as Map,
      ),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'email': email,
      'avatarUrl': avatarUrl,
      'points': points,
      'totalWeight': totalWeight,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastLoginAt': lastLoginAt != null ? Timestamp.fromDate(lastLoginAt!) : null,
      'provider': provider,
      'stats': stats,
    };
  }

  UserModel copyWith({
    String? name,
    String? email,
    String? avatarUrl,
    int? points,
    double? totalWeight,
    DateTime? lastLoginAt,
    Map<String, double>? stats,
  }) {
    return UserModel(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      points: points ?? this.points,
      totalWeight: totalWeight ?? this.totalWeight,
      createdAt: createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      provider: provider,
      stats: stats ?? this.stats,
    );
  }
}

