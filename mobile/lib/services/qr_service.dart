import 'package:cloud_firestore/cloud_firestore.dart';

/// Handles QR code scanning and claiming. Uses Firestore directly
/// (no Cloud Function required). Uses WriteBatch to avoid transaction
/// "Future already completed" issues on some Flutter/Firestore versions.
class QRService {
  QRService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const double _baseMultiplier = 100.0;
  static const double _freeBonus = 1.5;
  static const double _co2PointsMultiplier = 100.0;
  static const double _defaultCo2PerKg = 0.5;

  /// CO₂ saved per kg of each material type, keyed by material slug
  /// (the canonical `type` string stored on QR/transaction materials).
  static const Map<String, double> co2Multipliers = {
    'paper': 0.65,
    'plastic': 0.75,
    'glass': 0.30,
    'aluminum': 0.95,
    'batteries': 0.80,
    'electronics': 0.80,
    'food': 0.50,
    'lawn': 0.40,
    'used_oil': 0.70,
    'hazardous_waste': 0.90,
    'tires': 0.60,
    'metal': 0.85,
  };

  /// CO₂ saved (kg) for one material entry: the stored AI estimate when
  /// present (bin-created docs), otherwise weight × slug multiplier.
  static double materialCo2(String type, double weightKg, double? storedCo2) {
    if (storedCo2 != null) return storedCo2;
    return weightKg * (co2Multipliers[type] ?? _defaultCo2PerKg);
  }

  /// Claims a QR code for the current user. Returns points earned.
  /// Throws on error (e.g. already used, invalid qrId).
  Future<Map<String, dynamic>> scanQRCode(String qrId, String userId) async {
    final qrRef = _firestore.collection('qr_codes').doc(qrId);
    final qrDoc = await qrRef.get();
    if (!qrDoc.exists) {
      throw Exception('QR code not found');
    }
    final data = qrDoc.data()!;
    if (data['used'] == true) {
      throw Exception('This QR code has already been used');
    }
    final centerId = data['centerId'] as String?;
    if (centerId == null || centerId.isEmpty) {
      throw Exception('Invalid QR code');
    }
    final draft = data['transactionDraft'] as Map<String, dynamic>?;
    if (draft == null) {
      throw Exception('Invalid QR code data');
    }
    final materials = draft['materials'] as List<dynamic>? ?? [];
    final totalWeight = (draft['totalWeight'] as num?)?.toDouble() ?? 0.0;
    if (materials.isEmpty || totalWeight <= 0) {
      throw Exception('Invalid QR code data');
    }

    // points = round( Σ [ weight × 100 × (isFree ? 1.5 : 1) + co2 × 100 ] )
    // where co2 = stored value ?? weight × slug multiplier (0.5 default).
    double pointsRaw = 0;
    double co2Saved = 0;
    final transactionMaterials = <Map<String, dynamic>>[];
    for (final m in materials) {
      final map = m as Map<String, dynamic>;
      final weight = (map['weight'] as num?)?.toDouble() ?? 0.0;
      final type = (map['type'] as String?) ?? '';
      final isFree = map['isFree'] as bool? ?? true;
      final pricePerKg = (map['pricePerKg'] as num?)?.toDouble() ?? 0.0;
      final storedCo2 = (map['co2'] as num?)?.toDouble();
      final co2 = materialCo2(type, weight, storedCo2);
      pointsRaw += weight * _baseMultiplier * (isFree ? _freeBonus : 1.0) +
          co2 * _co2PointsMultiplier;
      co2Saved += co2;
      transactionMaterials.add({
        'type': type,
        'weight': weight,
        'pricePerKg': pricePerKg,
        'isFree': isFree,
        if (storedCo2 != null) 'co2': storedCo2,
      });
    }
    final pointsUser = pointsRaw.round();
    final pointsCenter = pointsUser;

    final userRef = _firestore.collection('users').doc(userId);
    final centerRef = _firestore.collection('centers').doc(centerId);
    final transactionsRef = _firestore.collection('transactions').doc();

    final userDoc = await userRef.get();
    final userData = userDoc.data() ?? {};
    final curPoints = (userData['points'] as num?)?.toInt() ?? 0;
    final curTotalWeight = (userData['totalWeight'] as num?)?.toDouble() ?? 0.0;
    final curCarbonFootprint =
        (userData['carbonFootprint'] as num?)?.toDouble() ?? 0.0;
    final curStats = Map<String, double>.from((userData['stats'] ?? {}) as Map);
    for (final m in transactionMaterials) {
      final type = m['type'] as String? ?? '';
      final w = (m['weight'] as num?)?.toDouble() ?? 0.0;
      curStats[type] = (curStats[type] ?? 0) + w;
    }

    final centerDoc = await centerRef.get();
    final centerData = centerDoc.data() ?? {};
    final cPoints = (centerData['points'] as num?)?.toInt() ?? 0;
    final cTotalWeight = (centerData['totalWeight'] as num?)?.toDouble() ?? 0.0;
    final cCarbonFootprint =
        (centerData['carbonFootprint'] as num?)?.toDouble() ?? 0.0;

    final batch = _firestore.batch();
    batch.update(qrRef, {
      'used': true,
      'usedBy': userId,
      'usedAt': FieldValue.serverTimestamp(),
    });
    batch.set(transactionsRef, {
      'userId': userId,
      'centerId': centerId,
      'materials': transactionMaterials,
      'totalWeight': totalWeight,
      'pointsUser': pointsUser,
      'pointsCenter': pointsCenter,
      'co2Saved': co2Saved,
      'createdAt': FieldValue.serverTimestamp(),
      'qrCodeId': qrId,
    });
    batch.set(userRef, {
      'points': curPoints + pointsUser,
      'totalWeight': curTotalWeight + totalWeight,
      'carbonFootprint': curCarbonFootprint + co2Saved,
      'stats': curStats,
    }, SetOptions(merge: true));
    batch.update(centerRef, {
      'points': cPoints + pointsCenter,
      'totalWeight': cTotalWeight + totalWeight,
      'carbonFootprint': cCarbonFootprint + co2Saved,
    });

    await batch.commit();

    return {
      'pointsUser': pointsUser,
      'co2Saved': co2Saved,
      'totalWeight': totalWeight,
    };
  }
}
