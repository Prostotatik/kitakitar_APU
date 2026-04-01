import 'package:flutter/foundation.dart';
import 'package:kitakitar_mobile/models/ai_scan_model.dart';

/// Holds scan result (detected waste materials) for use as map filters.
/// When user taps "Show on Map" after scan, these filters are applied on the map.
class ScanFiltersProvider extends ChangeNotifier {
  List<DetectedMaterial>? _detectedMaterials;
  bool _shouldSwitchToMap = false;
  int _scanVersion = 0;

  List<DetectedMaterial>? get detectedMaterials => _detectedMaterials;
  bool get shouldSwitchToMap => _shouldSwitchToMap;
  bool get hasFilters => _detectedMaterials != null && _detectedMaterials!.isNotEmpty;

  /// Increments each time setScanFilters is called so MapScreen can detect new scans.
  int get scanVersion => _scanVersion;

  /// Set filters from scan result. Call when user taps "Show on Map".
  void setScanFilters(List<DetectedMaterial> materials) {
    _detectedMaterials = materials;
    _shouldSwitchToMap = true;
    _scanVersion++;
    notifyListeners();
  }

  /// Reset the "switch to map" flag after MainScreen has handled it.
  void clearSwitchToMapFlag() {
    _shouldSwitchToMap = false;
    notifyListeners();
  }

  /// Clear all scan filters.
  void clearFilters() {
    _detectedMaterials = null;
    _shouldSwitchToMap = false;
    notifyListeners();
  }
}
