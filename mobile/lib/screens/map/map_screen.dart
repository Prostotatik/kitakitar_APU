import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:kitakitar_mobile/services/maps_service.dart';
import 'package:kitakitar_mobile/services/firestore_service.dart';
import 'package:kitakitar_mobile/models/center_model.dart';
import 'package:kitakitar_mobile/providers/scan_filters_provider.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapsService _mapsService = MapsService();
  final FirestoreService _firestoreService = FirestoreService();
  GoogleMapController? _mapController;
  List<CenterModel> _centers = [];

  /// Material types and labels (match center_web).
  static const List<Map<String, String>> _materialTypes = [
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

  // type -> requested weight (kg). If value is null, weight is not set.
  final Map<String, double?> _materialWeights = {
    for (final m in _MapScreenState._materialTypes) m['type']!: null,
  };

  // type -> whether this material is enabled in filters.
  final Map<String, bool> _materialSelected = {
    for (final m in _MapScreenState._materialTypes) m['type']!: false,
  };

  // Controllers for weight TextFields so programmatic updates are reflected in UI.
  late final Map<String, TextEditingController> _weightControllers;

  bool _showFilters = false;
  // Tracks which scanVersion has already been applied to avoid re-applying same scan.
  int _lastAppliedScanVersion = 0;

  String _materialLabel(String type) {
    final entry = _materialTypes.firstWhere(
      (m) => m['type'] == type,
      orElse: () => {'label': type},
    );
    return entry['label']!;
  }

  @override
  void initState() {
    super.initState();
    _weightControllers = {
      for (final m in _MapScreenState._materialTypes)
        m['type']!: TextEditingController(),
    };
    _loadCenters();
  }

  @override
  void dispose() {
    for (final c in _weightControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _applyScanFiltersIfNeeded();
  }

  void _applyScanFiltersIfNeeded() {
    // listen: true — subscribes MapScreen to provider changes so didChangeDependencies
    // is triggered whenever setScanFilters is called (new scan result arrives).
    final provider = Provider.of<ScanFiltersProvider>(context);
    if (provider.hasFilters && provider.scanVersion != _lastAppliedScanVersion) {
      _lastAppliedScanVersion = provider.scanVersion;
      final materials = provider.detectedMaterials!;

      // Reset all filters first, then apply only the detected ones.
      for (final type in _materialSelected.keys) {
        _materialSelected[type] = false;
        _materialWeights[type] = null;
        _weightControllers[type]?.clear();
      }

      for (final m in materials) {
        if (_materialWeights.containsKey(m.type)) {
          _materialSelected[m.type] = true;
          _materialWeights[m.type] = m.estimatedWeight;
          _weightControllers[m.type]?.text =
              m.estimatedWeight.toStringAsFixed(2);
        }
      }

      setState(() {
        _showFilters = true;
      });
      _loadCenters();
    }
  }

  Future<void> _loadCenters() async {
    // Always use local filter state (checkboxes + weights). Scan result only
    // populates that state; once user changes filters on map, we respect their choices.
    final filters = <String, double>{};
    _materialWeights.forEach((type, weight) {
      if ((_materialSelected[type] ?? false) && weight != null) {
        filters[type] = weight;
      }
    });
    final List<CenterModel> centers = await _firestoreService.getCenters(
      materialWeights: filters.isEmpty ? null : filters,
    );
    if (mounted) {
      setState(() {
        _centers = centers;
      });
    }
  }

  Set<Marker> _buildMarkers() {
    return _centers.map((center) {
      return Marker(
        markerId: MarkerId(center.id),
        position: LatLng(
          center.location.latitude,
          center.location.longitude,
        ),
        infoWindow: InfoWindow(
          title: center.name,
          snippet: center.address,
          onTap: () => _showCenterDetails(center),
        ),
        onTap: () => _showCenterDetails(center),
      );
    }).toSet();
  }

  Future<void> _showCenterDetails(CenterModel center) async {
    final materials =
        await _firestoreService.getCenterMaterials(center.id);
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  center.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  center.address,
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.stars_rounded, size: 18, color: Color(0xFF4CAF50)),
                    const SizedBox(width: 4),
                    Text(
                      '${center.points} pts',
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.scale, size: 18, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      '${center.totalWeight.toStringAsFixed(1)} kg collected',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Manager',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  center.manager.name,
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  center.manager.phone,
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Accepted materials',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                if (materials.isEmpty)
                  const Text('No materials configured for this center.')
                else
                  Column(
                    children: materials.map((m) {
                      final priceText = (m.pricePerKg ?? 0) <= 0
                          ? 'Free'
                          : '${m.pricePerKg!.toStringAsFixed(2)} / kg';
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(_materialLabel(m.type)),
                        subtitle: Text(
                          'From ${m.minWeight.toStringAsFixed(1)} kg '
                          'to ${m.maxWeight.toStringAsFixed(1)} kg • $priceText',
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Map'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              setState(() {
                _showFilters = !_showFilters;
              });
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              // Default to Malaysia center (same as center_web)
              target: LatLng(4.21, 101.98),
              zoom: 6,
            ),
            markers: _buildMarkers(),
            onMapCreated: (controller) {
              _mapController = controller;
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
          ),
          if (_showFilters)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Filters',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Column(
                      children: _materialWeights.keys.map((material) {
                        final isSelected = _materialSelected[material] ?? false;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Checkbox(
                                value: isSelected,
                                onChanged: (value) {
                                  setState(() {
                                    final v = value ?? false;
                                    _materialSelected[material] = v;
                                    if (!v) {
                                      _materialWeights[material] = null;
                                    }
                                  });
                                  _loadCenters();
                                },
                              ),
                              Expanded(
                                child: Text(
                                  _materialLabel(material),
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ),
                              const SizedBox(width: 12),
                              SizedBox(
                                width: 140,
                                child: TextField(
                                  controller: _weightControllers[material],
                                  enabled: isSelected,
                                  decoration: InputDecoration(
                                    labelText: 'Weight (kg)',
                                    hintText: 'e.g. 2.5',
                                    border: const OutlineInputBorder(),
                                    isDense: true,
                                    suffixIcon: _materialWeights[material] != null && isSelected
                                        ? IconButton(
                                            icon: const Icon(Icons.clear),
                                            onPressed: () {
                                              setState(() {
                                                _materialWeights[material] = null;
                                                _weightControllers[material]?.clear();
                                              });
                                              _loadCenters();
                                              FocusScope.of(context).unfocus();
                                            },
                                          )
                                        : null,
                                  ),
                                  keyboardType: TextInputType.number,
                                  onChanged: (value) {
                                    setState(() {
                                      _materialWeights[material] =
                                          value.trim().isEmpty ? null : double.tryParse(value);
                                    });
                                    _loadCenters();
                                  },
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

