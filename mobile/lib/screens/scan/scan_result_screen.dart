import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:kitakitar_mobile/models/ai_scan_model.dart';
import 'package:kitakitar_mobile/providers/scan_filters_provider.dart';
import 'package:kitakitar_mobile/screens/scan/recycling_chat_sheet.dart';

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
        return type;
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
                      borderRadius: BorderRadius.circular(12),
                      child: imagePath != null
                          ? Image.file(
                              File(imagePath!),
                              width: double.infinity,
                              height: 250,
                              fit: BoxFit.cover,
                            )
                          : CachedNetworkImage(
                              imageUrl: imageUrl!,
                              width: double.infinity,
                              height: 250,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(
                                height: 250,
                                color: Colors.grey.shade200,
                                child: const Center(child: CircularProgressIndicator()),
                              ),
                              errorWidget: (_, __, ___) => Container(
                                height: 250,
                                color: Colors.grey.shade200,
                                child: const Icon(Icons.broken_image, size: 48),
                              ),
                            ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  const Text(
                    'Detected Materials:',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...detectedMaterials.map((material) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          dense: true,
                          leading: const Icon(Icons.recycling, color: Color(0xFF4CAF50)),
                          title: Text(_getMaterialLabel(material.type)),
                          trailing: Text(
                            '${material.estimatedWeight.toStringAsFixed(2)} kg',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      )),
                  if (preparationTip != null && preparationTip!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Card(
                      color: Colors.blue.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.lightbulb_outline, color: Colors.blue.shade700, size: 22),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                preparationTip!,
                                style: TextStyle(fontSize: 14, color: Colors.blue.shade900),
                              ),
                            ),
                          ],
                        ),
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
                            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                          ),
                          builder: (_) => RecyclingChatSheet(
                            materials: detectedMaterials,
                            preparationTip: preparationTip,
                          ),
                        );
                      },
                      icon: const Icon(Icons.eco),
                      label: const Text('Ask AI'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        final provider = Provider.of<ScanFiltersProvider>(context, listen: false);
                        provider.setScanFilters(detectedMaterials);
                        context.go('/', extra: {'initialTab': 1});
                      },
                      icon: const Icon(Icons.map),
                      label: const Text('Show on Map'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
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

