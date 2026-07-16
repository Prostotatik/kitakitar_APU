class DetectedMaterial {
  final String type;
  final double estimatedWeight;

  DetectedMaterial({
    required this.type,
    required this.estimatedWeight,
  });

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'estimatedWeight': estimatedWeight,
    };
  }

  factory DetectedMaterial.fromMap(Map<String, dynamic> map) {
    return DetectedMaterial(
      type: map['type'] ?? '',
      estimatedWeight: (map['estimatedWeight'] ?? 0).toDouble(),
    );
  }
}

/// Result of AI scan: materials + optional preparation tip for drop-off.
class ScanResult {
  final List<DetectedMaterial> materials;
  final String? preparationTip;

  ScanResult({
    required this.materials,
    this.preparationTip,
  });

  Map<String, dynamic> toMap() {
    return {
      'detectedMaterials': materials.map((m) => m.toMap()).toList(),
      if (preparationTip != null) 'preparationTip': preparationTip,
    };
  }

  factory ScanResult.fromMap(Map<String, dynamic> map) {
    final list = map['detectedMaterials'] as List?;
    final materials = list
            ?.map((e) => DetectedMaterial.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList() ??
        [];
    return ScanResult(
      materials: materials,
      preparationTip: map['preparationTip'] as String?,
    );
  }
}

/// Persisted scan history entry from Firestore ai_scans collection.
class ScanHistoryItem {
  final String id;
  final String imageUrl;
  final List<DetectedMaterial> materials;
  final String? preparationTip;
  final DateTime createdAt;

  ScanHistoryItem({
    required this.id,
    required this.imageUrl,
    required this.materials,
    this.preparationTip,
    required this.createdAt,
  });

  String get materialsSummary =>
      materials.map((m) => m.type).join(', ');
}

