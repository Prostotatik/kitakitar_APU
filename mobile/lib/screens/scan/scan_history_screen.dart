import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:kitakitar_mobile/models/ai_scan_model.dart';
import 'package:kitakitar_mobile/services/firestore_service.dart';
import 'package:kitakitar_mobile/providers/auth_provider.dart';

class ScanHistoryScreen extends StatelessWidget {
  const ScanHistoryScreen({super.key});

  static final _dateFormat = DateFormat('dd MMM yyyy, HH:mm');

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
      case 'aluminum':
        return 'Aluminum';
      case 'batteries':
        return 'Batteries';
      case 'electronics':
        return 'Electronics';
      case 'food':
        return 'Food';
      case 'cardboard':
        return 'Cardboard';
      case 'tires':
        return 'Tires';
      case 'used_oil':
        return 'Used Oil';
      case 'hazardous':
        return 'Hazardous';
      default:
        return type[0].toUpperCase() + type.substring(1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = Provider.of<AuthProvider>(context, listen: false).user?.uid;

    if (userId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Scan History')),
        body: const Center(child: Text('Please log in to view history.')),
      );
    }

    final firestoreService = FirestoreService();

    return Scaffold(
      appBar: AppBar(title: const Text('Scan History')),
      body: StreamBuilder<List<ScanHistoryItem>>(
        stream: firestoreService.getScanHistory(userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final items = snapshot.data ?? [];

          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 80, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text(
                    'No scans yet',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your scan history will appear here',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final item = items[index];
              final materialLabels = item.materials
                  .map((m) => _getMaterialLabel(m.type))
                  .join(', ');

              return Card(
                clipBehavior: Clip.antiAlias,
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: InkWell(
                  onTap: () {
                    context.push('/scan-result', extra: {
                      'detectedMaterials': item.materials,
                      'preparationTip': item.preparationTip,
                      'imageUrl': item.imageUrl,
                    });
                  },
                  child: Row(
                    children: [
                      SizedBox(
                        width: 100,
                        height: 100,
                        child: CachedNetworkImage(
                          imageUrl: item.imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            color: Colors.grey.shade200,
                            child: const Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                          ),
                          errorWidget: (_, __, ___) => Container(
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.broken_image, color: Colors.grey),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                materialLabels.isNotEmpty
                                    ? materialLabels
                                    : 'Unknown',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _dateFormat.format(item.createdAt),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.only(right: 12),
                        child: Icon(
                          Icons.chevron_right,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
