import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:kitakitar_mobile/services/maps_service.dart';
import 'package:kitakitar_mobile/services/firestore_service.dart';
import 'package:kitakitar_mobile/models/center_model.dart';
import 'package:kitakitar_mobile/providers/scan_filters_provider.dart';
import 'package:kitakitar_mobile/theme/app_theme.dart';

/// Kuala Lumpur city center (default map view).
const LatLng _kualaLumpurCenter = LatLng(3.1390, 101.6869);

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
  BitmapDescriptor? _customPin;

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

  final Map<String, double?> _materialWeights = {
    for (final m in _MapScreenState._materialTypes) m['type']!: null,
  };

  final Map<String, bool> _materialSelected = {
    for (final m in _MapScreenState._materialTypes) m['type']!: false,
  };

  late final Map<String, TextEditingController> _weightControllers;

  bool _showFilters = false;
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
    _createCustomPin();
    _loadCenters();
  }

  Future<void> _createCustomPin() async {
    final descriptor = await _paintMarker();
    if (mounted) setState(() => _customPin = descriptor);
  }

  static Future<BitmapDescriptor> _paintMarker() async {
    const double w = 96;
    const double bubbleH = 70;
    const double pointerH = 14;
    const double h = bubbleH + pointerH;
    const double r = 14;
    const double tw = 11;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, w, h));

    final shadowPaint = Paint()
      ..color = const Color(0x40000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(2, 2, w - 4, bubbleH - 2),
        const Radius.circular(r),
      ),
      shadowPaint,
    );

    final bubbleRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(0, 0, w, bubbleH),
      const Radius.circular(r),
    );
    final fillPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, 0),
        Offset(0, bubbleH),
        [Color(0xFF00C853), Color(0xFF2E7D32)],
      );
    canvas.drawRRect(bubbleRect, fillPaint);

    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = Colors.white;
    canvas.drawRRect(bubbleRect, borderPaint);

    final pointerPath = Path()
      ..moveTo(w / 2 - tw, bubbleH - 2)
      ..lineTo(w / 2, h)
      ..lineTo(w / 2 + tw, bubbleH - 2)
      ..close();
    canvas.drawPath(pointerPath, Paint()..color = const Color(0xFF2E7D32));
    canvas.drawPath(
      pointerPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = Colors.white,
    );
    canvas.drawRect(
      Rect.fromLTWH(w / 2 - tw + 1, bubbleH - 4, tw * 2 - 2, 4),
      Paint()..color = const Color(0xFF2E7D32),
    );

    final iconPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(Icons.recycling.codePoint),
        style: TextStyle(
          fontSize: 34,
          fontFamily: Icons.recycling.fontFamily,
          package: Icons.recycling.fontPackage,
          color: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    iconPainter.layout();
    iconPainter.paint(
      canvas,
      Offset(
        (w - iconPainter.width) / 2,
        (bubbleH - iconPainter.height) / 2 - 1,
      ),
    );

    final picture = recorder.endRecording();
    final img = await picture.toImage(w.toInt(), h.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.bytes(byteData!.buffer.asUint8List());
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
    final provider = Provider.of<ScanFiltersProvider>(context);
    if (provider.hasFilters &&
        provider.scanVersion != _lastAppliedScanVersion) {
      _lastAppliedScanVersion = provider.scanVersion;
      final materials = provider.detectedMaterials!;

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
        icon: _customPin ??
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        anchor: const Offset(0.5, 1.0),
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
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.55,
          minChildSize: 0.3,
          maxChildSize: 0.85,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 12),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Header with gradient
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1B5E20), Color(0xFF43A047)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1B5E20).withAlpha(40),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          right: -8,
                          top: -8,
                          child: Icon(Icons.recycling_rounded,
                              size: 50, color: Colors.white.withAlpha(15)),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withAlpha(30),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.store_rounded,
                                      color: Colors.white, size: 22),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    center.name,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Icon(Icons.location_on_rounded,
                                    size: 14,
                                    color: Colors.white.withAlpha(180)),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    center.address,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.white.withAlpha(200),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Stat chips
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: _DetailChip(
                            icon: Icons.stars_rounded,
                            iconColor: const Color(0xFFFFC107),
                            label: '${center.points} pts',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _DetailChip(
                            icon: Icons.scale_rounded,
                            iconColor: AppColors.primary,
                            label:
                                '${center.totalWeight.toStringAsFixed(1)} kg',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _DetailChip(
                            icon: Icons.eco_rounded,
                            iconColor: AppColors.primary,
                            label:
                                '${center.carbonFootprint.toStringAsFixed(1)} CO\u2082',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Manager section
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildSectionLabel('Manager'),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.primary.withAlpha(40),
                                AppColors.primary.withAlpha(20),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.person_outline,
                              size: 20, color: AppColors.primary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                center.manager.name,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                center.manager.phone,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withAlpha(15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.phone_outlined,
                              size: 18, color: AppColors.primary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Materials section
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildSectionLabel('Accepted materials'),
                  ),
                  const SizedBox(height: 10),
                  if (materials.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.inbox_rounded,
                                size: 32, color: Colors.grey.shade300),
                            const SizedBox(height: 8),
                            Text(
                              'No materials configured',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: materials.map((m) {
                          final priceText = (m.pricePerKg ?? 0) <= 0
                              ? 'Free'
                              : '${m.pricePerKg!.toStringAsFixed(2)} / kg';
                          final isFree = (m.pricePerKg ?? 0) <= 0;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border:
                                  Border.all(color: Colors.grey.shade200),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.shade100,
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withAlpha(15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.recycling,
                                      size: 16, color: AppColors.primary),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _materialLabel(m.type),
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Text(
                                        '${m.minWeight.toStringAsFixed(1)} – ${m.maxWeight.toStringAsFixed(1)} kg',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey.shade500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isFree
                                        ? const Color(0xFFE8F5E9)
                                        : const Color(0xFFF1F8E9),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    priceText,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: isFree
                                          ? AppColors.primary
                                          : AppColors.primaryDark,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSectionLabel(String label) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  int get _activeFilterCount =>
      _materialSelected.values.where((v) => v).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: _kualaLumpurCenter,
              zoom: 11,
            ),
            markers: _buildMarkers(),
            onMapCreated: (controller) {
              _mapController = controller;
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            padding: const EdgeInsets.only(bottom: 80),
          ),

          // Top bar overlay
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 8,
                left: 16,
                right: 16,
                bottom: 12,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white,
                    Colors.white.withAlpha(240),
                    Colors.white.withAlpha(0),
                  ],
                  stops: const [0, 0.7, 1.0],
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(15),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.map_rounded,
                            size: 20, color: AppColors.primary),
                        const SizedBox(width: 8),
                        const Text(
                          'Recycling Map',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  _buildCenterCount(),
                  const SizedBox(width: 8),
                  _buildFilterButton(),
                ],
              ),
            ),
          ),

          // My location button
          Positioned(
            bottom: 24,
            right: 16,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(18),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () {
                    _mapController?.animateCamera(
                      CameraUpdate.newLatLng(_kualaLumpurCenter),
                    );
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(12),
                    child: Icon(Icons.my_location_rounded,
                        color: AppColors.primary, size: 22),
                  ),
                ),
              ),
            ),
          ),

          // Bottom info pill
          Positioned(
            bottom: 24,
            left: 24,
            right: 80,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(15),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 18, color: AppColors.primary),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Tap a pin to see center details',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Filter panel
          if (_showFilters)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              bottom: 0,
              child: GestureDetector(
                onTap: () => setState(() => _showFilters = false),
                child: Container(color: Colors.black26),
              ),
            ),
          if (_showFilters)
            Positioned(
              top: MediaQuery.of(context).padding.top + 60,
              left: 12,
              right: 12,
              child: Material(
                elevation: 8,
                shadowColor: Colors.black26,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.55,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withAlpha(15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.filter_list_rounded,
                                  size: 18, color: AppColors.primary),
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'Filter by material',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const Spacer(),
                            if (_activeFilterCount > 0)
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    for (final type
                                        in _materialSelected.keys) {
                                      _materialSelected[type] = false;
                                      _materialWeights[type] = null;
                                      _weightControllers[type]?.clear();
                                    }
                                  });
                                  _loadCenters();
                                },
                                child: const Text('Clear all'),
                              ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 20),
                              onPressed: () =>
                                  setState(() => _showFilters = false),
                            ),
                          ],
                        ),
                      ),
                      Divider(height: 1, color: Colors.grey.shade200),
                      Flexible(
                        child: ListView(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          shrinkWrap: true,
                          children:
                              _materialWeights.keys.map((material) {
                            final isSelected =
                                _materialSelected[material] ?? false;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 28,
                                    height: 28,
                                    child: Checkbox(
                                      value: isSelected,
                                      visualDensity: VisualDensity.compact,
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(6),
                                      ),
                                      onChanged: (value) {
                                        setState(() {
                                          final v = value ?? false;
                                          _materialSelected[material] = v;
                                          if (!v) {
                                            _materialWeights[material] =
                                                null;
                                          }
                                        });
                                        _loadCenters();
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _materialLabel(material),
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: isSelected
                                            ? FontWeight.w600
                                            : FontWeight.w400,
                                        color: isSelected
                                            ? AppColors.textPrimary
                                            : AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  SizedBox(
                                    width: 110,
                                    height: 40,
                                    child: TextField(
                                      controller:
                                          _weightControllers[material],
                                      enabled: isSelected,
                                      style:
                                          const TextStyle(fontSize: 13),
                                      decoration: InputDecoration(
                                        labelText: 'kg',
                                        hintText: '0.0',
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 8),
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          borderSide: BorderSide(
                                              color: Colors.grey.shade300),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          borderSide: BorderSide(
                                              color: Colors.grey.shade300),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          borderSide: const BorderSide(
                                              color: AppColors.primary,
                                              width: 1.5),
                                        ),
                                        isDense: true,
                                        filled: true,
                                        fillColor: isSelected
                                            ? Colors.white
                                            : Colors.grey.shade100,
                                        suffixIcon: _materialWeights[
                                                        material] !=
                                                    null &&
                                                isSelected
                                            ? GestureDetector(
                                                onTap: () {
                                                  setState(() {
                                                    _materialWeights[
                                                        material] = null;
                                                    _weightControllers[
                                                            material]
                                                        ?.clear();
                                                  });
                                                  _loadCenters();
                                                  FocusScope.of(context)
                                                      .unfocus();
                                                },
                                                child: const Icon(
                                                    Icons.clear,
                                                    size: 16),
                                              )
                                            : null,
                                      ),
                                      keyboardType:
                                          TextInputType.number,
                                      onChanged: (value) {
                                        setState(() {
                                          _materialWeights[material] =
                                              value.trim().isEmpty
                                                  ? null
                                                  : double.tryParse(value);
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
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCenterCount() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.store_rounded, size: 16, color: AppColors.primary),
          const SizedBox(width: 4),
          Text(
            '${_centers.length}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButton() {
    return Container(
      decoration: BoxDecoration(
        color: _activeFilterCount > 0
            ? AppColors.primary
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() => _showFilters = !_showFilters),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _showFilters
                      ? Icons.filter_list_off
                      : Icons.filter_list_rounded,
                  size: 20,
                  color: _activeFilterCount > 0
                      ? Colors.white
                      : AppColors.textSecondary,
                ),
                if (_activeFilterCount > 0) ...[
                  const SizedBox(width: 4),
                  Container(
                    width: 18,
                    height: 18,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '$_activeFilterCount',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailChip extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;

  const _DetailChip({
    required this.icon,
    required this.iconColor,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: iconColor.withAlpha(12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: iconColor.withAlpha(30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: iconColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
