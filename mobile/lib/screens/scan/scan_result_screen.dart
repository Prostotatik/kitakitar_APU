import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:kitakitar_mobile/models/ai_scan_model.dart';
import 'package:kitakitar_mobile/providers/scan_filters_provider.dart';
import 'package:kitakitar_mobile/screens/scan/recycling_chat_sheet.dart';
import 'package:kitakitar_mobile/theme/app_theme.dart';

class ScanResultScreen extends StatelessWidget {
  final List<DetectedMaterial> detectedMaterials;
  final String? preparationTip;
  final String? imagePath;
  final String? imageUrl;

  const ScanResultScreen({
    super.key,
    required this.detectedMaterials,
    this.preparationTip,
    this.imagePath,
    this.imageUrl,
  });

  static const _materialIcons = <String, IconData>{
    'plastic': Icons.local_drink_outlined,
    'paper': Icons.description_outlined,
    'glass': Icons.wine_bar_outlined,
    'metal': Icons.settings_outlined,
    'aluminum': Icons.crop_square_outlined,
    'cardboard': Icons.inventory_2_outlined,
    'batteries': Icons.battery_full_outlined,
    'electronics': Icons.devices_outlined,
    'food': Icons.restaurant_outlined,
    'tires': Icons.trip_origin_outlined,
  };

  static const _materialColors = <String, Color>{
    'plastic': Color(0xFF2196F3),
    'paper': Color(0xFF795548),
    'glass': Color(0xFF00BCD4),
    'metal': Color(0xFF607D8B),
    'aluminum': Color(0xFF9E9E9E),
    'cardboard': Color(0xFF8D6E63),
    'batteries': Color(0xFFFF9800),
    'electronics': Color(0xFF673AB7),
    'food': Color(0xFF4CAF50),
    'tires': Color(0xFF212121),
  };

  String _getMaterialLabel(String type) {
    switch (type.toLowerCase()) {
      case 'plastic':
        return 'Plastic';
      case 'paper':
        return 'Paper';
      case 'glass':
        return 'Glass';
      case 'metal':
        return 'Metal';
      default:
        return type[0].toUpperCase() + type.substring(1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Result'),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (imagePath != null || imageUrl != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: imagePath != null
                          ? Image.file(
                              File(imagePath!),
                              width: double.infinity,
                              height: 220,
                              fit: BoxFit.cover,
                            )
                          : CachedNetworkImage(
                              imageUrl: imageUrl!,
                              width: double.infinity,
                              height: 220,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(
                                height: 220,
                                color: Colors.grey.shade200,
                                child: const Center(
                                    child: CircularProgressIndicator()),
                              ),
                              errorWidget: (_, __, ___) => Container(
                                height: 220,
                                color: Colors.grey.shade200,
                                child: const Icon(Icons.broken_image, size: 48),
                              ),
                            ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  Row(
                    children: [
                      Container(
                        width: 4,
                        height: 22,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Detected Materials',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight.withAlpha(25),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${detectedMaterials.length} found',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...detectedMaterials.map((material) {
                    final typeKey = material.type.toLowerCase();
                    final color =
                        _materialColors[typeKey] ?? AppColors.primary;
                    final icon = _materialIcons[typeKey] ?? Icons.recycling;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: color.withAlpha(25),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(icon, color: color, size: 22),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                _getMaterialLabel(material.type),
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: color.withAlpha(18),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${material.estimatedWeight.toStringAsFixed(2)} kg',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: color,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  if (preparationTip != null &&
                      preparationTip!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: AppColors.primaryLight.withAlpha(40)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight.withAlpha(30),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.lightbulb_outline_rounded,
                              color: AppColors.primary,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Preparation Tip',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  preparationTip!,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade800,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.white,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(
                                top: Radius.circular(20)),
                          ),
                          builder: (_) => RecyclingChatSheet(
                            materials: detectedMaterials,
                            preparationTip: preparationTip,
                          ),
                        );
                      },
                      icon: const Icon(Icons.eco_outlined, size: 20),
                      label: const Text('Ask AI'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        final provider = Provider.of<ScanFiltersProvider>(
                            context,
                            listen: false);
                        provider.setScanFilters(detectedMaterials);
                        context.go('/', extra: {'initialTab': 1});
                      },
                      icon: const Icon(Icons.map_outlined, size: 20),
                      label: const Text('Show on Map'),
                    ),
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
