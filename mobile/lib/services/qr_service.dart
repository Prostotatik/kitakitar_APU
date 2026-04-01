import 'package:cloud_firestore/cloud_firestore.dart';

/// Handles QR code scanning and claiming. Uses Firestore directly
/// (no Cloud Function required). Uses WriteBatch to avoid transaction
/// "Future already completed" issues on some Flutter/Firestore versions.
class QRService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const double _baseMultiplier = 100.0;

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

    int pointsUser = 0;
    final transactionMaterials = <Map<String, dynamic>>[];
    for (final m in materials) {
      final map = m as Map<String, dynamic>;
      final weight = (map['weight'] as num?)?.toDouble() ?? 0.0;
      final isFree = map['isFree'] as bool? ?? true;
      final pricePerKg = (map['pricePerKg'] as num?)?.toDouble() ?? 0.0;
      final pts = (isFree ? weight * _baseMultiplier * 1.5 : weight * _baseMultiplier).round();
      pointsUser += pts;
      transactionMaterials.add({
        'type': map['type'] ?? '',
        'weight': weight,
        'pricePerKg': pricePerKg,
        'isFree': isFree,
      });
    }
    final pointsCenter = pointsUser;

    final userRef = _firestore.collection('users').doc(userId);
    final centerRef = _firestore.collection('centers').doc(centerId);
    final transactionsRef = _firestore.collection('transactions').doc();

    final userDoc = await userRef.get();
    final userData = userDoc.data() ?? {};
    final curPoints = (userData['points'] as num?)?.toInt() ?? 0;
    final curTotalWeight = (userData['totalWeight'] as num?)?.toDouble() ?? 0.0;
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
      'createdAt': FieldValue.serverTimestamp(),
      'qrCodeId': qrId,
    });
    batch.set(userRef, {
      'points': curPoints + pointsUser,
      'totalWeight': curTotalWeight + totalWeight,
      'stats': curStats,
    }, SetOptions(merge: true));
    batch.update(centerRef, {
      'points': cPoints + pointsCenter,
      'totalWeight': cTotalWeight + totalWeight,
    });

    await batch.commit();

    return {
      'pointsUser': pointsUser,
      'totalWeight': totalWeight,
    };
  }
}
