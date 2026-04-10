import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kitakitar_mobile/models/user_model.dart';
import 'package:kitakitar_mobile/models/center_model.dart';
import 'package:kitakitar_mobile/models/ai_scan_model.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Users
  Future<void> createUser(UserModel user) async {
    await _firestore.collection('users').doc(user.id).set(user.toFirestore());
  }

  Future<UserModel?> getUser(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    if (!doc.exists) return null;
    return UserModel.fromFirestore(doc);
  }

  Stream<UserModel?> getUserStream(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((doc) => doc.exists ? UserModel.fromFirestore(doc) : null);
  }

  Future<void> updateUser(String userId, Map<String, dynamic> data) async {
    await _firestore.collection('users').doc(userId).update(data);
  }

  // Centers
  Stream<List<CenterModel>> getCentersStream() {
    Query query = _firestore
        .collection('centers')
        .where('isActive', isEqualTo: true);

    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => CenterModel.fromFirestore(doc))
          .toList();
    });
  }

  Future<List<CenterModel>> getCenters({
    Map<String, double?>? materialWeights,
  }) async {
    Query query = _firestore
        .collection('centers')
        .where('isActive', isEqualTo: true);

    final snapshot = await query.get();
    final centers = snapshot.docs
        .map((doc) => CenterModel.fromFirestore(doc))
        .toList();

    // Filter by materials/weights if requested
    final activeFilters = materialWeights
            ?.entries
            .where((e) => e.value != null)
            .toList() ??
        [];
    if (activeFilters.isNotEmpty) {
      final filteredCenters = <CenterModel>[];
      for (final center in centers) {
        final materialsSnapshot = await _firestore
            .collection('centers')
            .doc(center.id)
            .collection('materials')
            .get();

        final hasMaterial = materialsSnapshot.docs.any((doc) {
          final material = CenterMaterial.fromFirestore(doc);
          // A center matches if it can accept at least one of the
          // requested (materialType, weight) pairs.
          return activeFilters.any((f) {
            final requestedType = f.key;
            final requestedWeight = f.value!;
            if (material.type != requestedType) return false;
            return requestedWeight >= material.minWeight &&
                requestedWeight <= material.maxWeight;
          });
        });

        if (hasMaterial) {
          filteredCenters.add(center);
        }
      }
      return filteredCenters;
    }

    return centers;
  }

  /// Returns centers that accept at least one of the detected materials:
  /// for each (type, weight) the center must have a material with that type
  /// and weight within [minWeight, maxWeight] of that material.
  Future<List<CenterModel>> getCentersForDetectedMaterials(
    List<DetectedMaterial> detected,
  ) async {
    if (detected.isEmpty) return getCenters();

    final snapshot = await _firestore
        .collection('centers')
        .where('isActive', isEqualTo: true)
        .get();

    final result = <CenterModel>[];
    for (final doc in snapshot.docs) {
      final center = CenterModel.fromFirestore(doc);
      final materialsSnapshot = await _firestore
          .collection('centers')
          .doc(center.id)
          .collection('materials')
          .get();

      final centerMaterials = materialsSnapshot.docs
          .map((d) => CenterMaterial.fromFirestore(d))
          .toList();

      final acceptsAtLeastOne = detected.any((d) {
        return centerMaterials.any((m) =>
            m.acceptsMaterial(d.type, d.estimatedWeight));
      });

      if (acceptsAtLeastOne) {
        result.add(center);
      }
    }
    return result;
  }

  Future<List<CenterMaterial>> getCenterMaterials(String centerId) async {
    final snapshot = await _firestore
        .collection('centers')
        .doc(centerId)
        .collection('materials')
        .get();

    return snapshot.docs
        .map((doc) => CenterMaterial.fromFirestore(doc))
        .toList();
  }

  // AI Scans
  Future<void> saveAiScan(
    String userId,
    String imageUrl,
    List<Map<String, dynamic>> detectedMaterials, {
    String? preparationTip,
  }) async {
    await _firestore.collection('ai_scans').add({
      'userId': userId,
      'imageUrl': imageUrl,
      'detectedMaterials': detectedMaterials,
      if (preparationTip != null) 'preparationTip': preparationTip,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<ScanHistoryItem>> getScanHistory(String userId) {
    return _firestore
        .collection('ai_scans')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              final rawMaterials = data['detectedMaterials'] as List? ?? [];
              return ScanHistoryItem(
                id: doc.id,
                imageUrl: data['imageUrl'] ?? '',
                materials: rawMaterials
                    .map((e) => DetectedMaterial.fromMap(
                        Map<String, dynamic>.from(e as Map)))
                    .toList(),
                preparationTip: data['preparationTip'] as String?,
                createdAt: (data['createdAt'] as Timestamp?)?.toDate() ??
                    DateTime.now(),
              );
            }).toList());
  }

  // Leaderboards (mobile app)
  //
  // Cache in /leaderboards in idea.md is optional, so
  // for the mobile client it is simpler and more reliable to read
  // directly from the base collections /users and /centers, sorting
  // by the required field.
  //
  // [type]   - "users" or "centers"
  // [metric] - field to sort by, "points" by default
  Stream<List<QueryDocumentSnapshot>> getLeaderboard(
    String type, {
    String metric = 'points',
  }) {
    final String collection =
        type == 'centers' ? 'centers' : 'users';

    return _firestore
        .collection(collection)
        .snapshots()
        .map((snap) {
      final docs = snap.docs.toList();
      docs.sort((a, b) {
        final aVal = (a.data()[metric] as num?)?.toDouble() ?? 0.0;
        final bVal = (b.data()[metric] as num?)?.toDouble() ?? 0.0;
        return bVal.compareTo(aVal);
      });
      if (docs.length > 100) return docs.sublist(0, 100);
      return docs;
    });
  }

  // Transactions
  Stream<QuerySnapshot> getUserTransactions(String userId) {
    return _firestore
        .collection('transactions')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// One-time backfill: recalculate carbonFootprint for ALL users & centers
  /// from existing transactions. Also ensures every user/center document
  /// has the field (set to 0 if no transactions), so orderBy queries work.
  Future<int> backfillCarbonFootprint() async {
    const co2 = <String, double>{
      'Paper/Cardboard': 0.65,
      'Plastics': 0.75,
      'Glass': 0.30,
      'Aluminum': 0.95,
      'Batteries': 0.80,
      'Electronics': 0.80,
      'Food': 0.50,
      'Lawn Materials': 0.40,
      'Used Oil': 0.70,
      'Household Hazardous Waste': 0.90,
      'Tires': 0.60,
      'Metal': 0.85,
    };

    final txSnap = await _firestore.collection('transactions').get();

    final userTotals = <String, double>{};
    final centerTotals = <String, double>{};

    for (final doc in txSnap.docs) {
      final data = doc.data();
      final userId = data['userId'] as String? ?? '';
      final centerId = data['centerId'] as String? ?? '';
      final materials = data['materials'] as List<dynamic>? ?? [];

      double txCo2 = 0;
      for (final m in materials) {
        final map = m as Map<String, dynamic>;
        final type = (map['type'] as String?) ?? '';
        final weight = (map['weight'] as num?)?.toDouble() ?? 0.0;
        txCo2 += weight * (co2[type] ?? 0.5);
      }

      if (userId.isNotEmpty) {
        userTotals[userId] = (userTotals[userId] ?? 0) + txCo2;
      }
      if (centerId.isNotEmpty) {
        centerTotals[centerId] = (centerTotals[centerId] ?? 0) + txCo2;
      }
    }

    // Ensure ALL users and centers get the field (0 if no transactions)
    final allUsers = await _firestore.collection('users').get();
    final allCenters = await _firestore.collection('centers').get();

    final batch = _firestore.batch();
    for (final doc in allUsers.docs) {
      batch.set(
        doc.reference,
        {'carbonFootprint': userTotals[doc.id] ?? 0.0},
        SetOptions(merge: true),
      );
    }
    for (final doc in allCenters.docs) {
      batch.set(
        doc.reference,
        {'carbonFootprint': centerTotals[doc.id] ?? 0.0},
        SetOptions(merge: true),
      );
    }
    await batch.commit();

    return txSnap.docs.length;
  }
}

