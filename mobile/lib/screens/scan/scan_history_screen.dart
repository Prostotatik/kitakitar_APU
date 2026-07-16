import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:kitakitar_mobile/models/ai_scan_model.dart';
import 'package:kitakitar_mobile/services/firestore_service.dart';
import 'package:kitakitar_mobile/providers/auth_provider.dart';
import 'package:kitakitar_mobile/theme/app_theme.dart';

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
    final userId =
        Provider.of<AuthProvider>(context, listen: false).user?.uid;

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
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.history_rounded,
                        size: 40, color: Colors.grey.shade400),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'No scans yet',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Your scan history will appear here',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = items[index];
              final materialLabels = item.materials
                  .map((m) => _getMaterialLabel(m.type))
                  .join(', ');

              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () {
                    context.push('/scan-result', extra: {
                      'detectedMaterials': item.materials,
                      'preparationTip': item.preparationTip,
                      'imageUrl': item.imageUrl,
                    });
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(14),
                          bottomLeft: Radius.circular(14),
                        ),
                        child: SizedBox(
                          width: 90,
                          height: 90,
                          child: CachedNetworkImage(
                            imageUrl: item.imageUrl,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                              color: Colors.grey.shade100,
                              child: const Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                ),
                              ),
                            ),
                            errorWidget: (_, __, ___) => Container(
                              color: Colors.grey.shade100,
                              child: Icon(Icons.broken_image,
                                  color: Colors.grey.shade400),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                materialLabels.isNotEmpty
                                    ? materialLabels
                                    : 'Unknown',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(Icons.access_time,
                                      size: 14,
                                      color: Colors.grey.shade500),
                                  const SizedBox(width: 4),
                                  Text(
                                    _dateFormat.format(item.createdAt),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Icon(
                          Icons.chevron_right,
                          color: Colors.grey.shade400,
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
