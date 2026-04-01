import 'package:flutter/foundation.dart';

import '../models/center_material.dart';
import '../models/center_profile.dart';
import '../services/center_firestore_service.dart';

/// Holds center profile and materials loaded from Firestore. Call [load] when user is logged in.
class CenterDataProvider with ChangeNotifier {
  final CenterFirestoreService _firestore = CenterFirestoreService();

  CenterProfile? _center;
  List<CenterMaterialEntry> _materials = [];
  bool _loading = false;
  String? _error;
  String? _centerId;

  CenterProfile? get center => _center;
  List<CenterMaterialEntry> get materials => List.unmodifiable(_materials);
  bool get loading => _loading;
  String? get error => _error;
  String? get centerId => _centerId;

  /// Load center doc and materials for [centerId]. Idempotent if same centerId already loaded.
  Future<void> load(String centerId) async {
    if (_centerId == centerId && _center != null && _error == null) return;
    _centerId = centerId;
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _firestore.getCenter(centerId),
        _firestore.getMaterials(centerId),
      ]);
      final profile = results[0] as CenterProfile?;
      final mats = results[1] as List<CenterMaterialEntry>;

      _center = profile;
      _materials = mats;
      _error = profile == null ? 'Center not found' : null;
    } catch (e) {
      _center = null;
      _materials = [];
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Clear and optionally reload (e.g. after logout or refresh).
  void clear() {
    _center = null;
    _materials = [];
    _centerId = null;
    _error = null;
    notifyListeners();
  }

  /// Reload current center. No-op if no centerId.
  Future<void> refresh() async {
    if (_centerId == null) return;
    final id = _centerId!;
    _center = null;
    await load(id);
  }
}
