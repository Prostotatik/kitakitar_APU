import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:kitakitar_mobile/services/ai_service.dart';
import 'package:kitakitar_mobile/services/firestore_service.dart';
import 'package:kitakitar_mobile/services/storage_service.dart';
import 'package:kitakitar_mobile/providers/auth_provider.dart';
import 'package:kitakitar_mobile/theme/cyberpunk_theme.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen>
    with SingleTickerProviderStateMixin {
  final AIService _aiService = AIService();
  final FirestoreService _firestoreService = FirestoreService();
  final StorageService _storageService = StorageService();
  final ImagePicker _picker = ImagePicker();
  bool _isProcessing = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _showImageSourcePicker() {
    if (_isProcessing) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: CyberpunkColors.backgroundMoss,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(2)),
        side: BorderSide(color: CyberpunkColors.neonGreen, width: 2),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'SELECT IMAGE SOURCE',
                style: CyberpunkText.pixelHeading(
                  fontSize: 12,
                  color: CyberpunkColors.neonGreen,
                ),
              ),
              const SizedBox(height: 24),
              _CyberpunkListTile(
                icon: Icons.camera_alt,
                title: 'TAKE A PHOTO',
                subtitle: 'Capture waste with camera',
                onTap: () {
                  Navigator.pop(context);
                  _pickAndProcessImage(ImageSource.camera);
                },
              ),
              _CyberpunkListTile(
                icon: Icons.photo_library,
                title: 'CHOOSE FROM GALLERY',
                subtitle: 'Upload existing photo',
                onTap: () {
                  Navigator.pop(context);
                  _pickAndProcessImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickAndProcessImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 85,
      );

      if (image == null) return;

      setState(() {
        _isProcessing = true;
      });

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.user?.uid;
      if (userId == null) return;

      final imageUrl = await _storageService.uploadImage(
        File(image.path),
        userId,
      );

      final scanResult = await _aiService.detectMaterials(image.path);

      await _firestoreService.saveAiScan(
        userId,
        imageUrl,
        scanResult.materials.map((m) => m.toMap()).toList(),
        preparationTip: scanResult.preparationTip,
      );

      if (mounted) {
        setState(() {
          _isProcessing = false;
        });

        context.push('/scan-result', extra: {
          'detectedMaterials': scanResult.materials,
          'preparationTip': scanResult.preparationTip,
          'imagePath': image.path,
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ERROR: $e', style: CyberpunkText.bodyText()),
            backgroundColor: CyberpunkColors.backgroundMoss,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('SCAN', style: CyberpunkText.pixelHeading(fontSize: 12)),
        backgroundColor: CyberpunkColors.backgroundDeep,
        elevation: 0,
      ),
      body: Stack(
        children: [
          CircuitGridBackground(
            child: GestureDetector(
              onTap: _isProcessing ? null : _showImageSourcePicker,
              child: Container(
                width: double.infinity,
                height: double.infinity,
                child: _isProcessing
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const CircularProgressIndicator(
                              color: CyberpunkColors.neonGreen,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'PROCESSING IMAGE...',
                              style: CyberpunkText.pixelHeading(
                                fontSize: 12,
                                color: CyberpunkColors.electricLime,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'AI ANALYSIS IN PROGRESS',
                              style: CyberpunkText.bodyText(
                                color: CyberpunkColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      )
                    : Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Animated scan icon
                            AnimatedBuilder(
                              animation: _pulseAnimation,
                              builder: (context, child) {
                                return Container(
                                  width: 140,
                                  height: 140,
                                  decoration: BoxDecoration(
                                    color: CyberpunkColors.backgroundJungle,
                                    borderRadius: BorderRadius.circular(2),
                                    border: Border.all(
                                      color: CyberpunkColors.neonGreen,
                                      width: 3,
                                    ),
                                    boxShadow: CyberpunkGlow.greenGlow(
                                      intensity: _pulseAnimation.value,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt,
                                    size: 60,
                                    color: CyberpunkColors.neonGreen,
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 32),
                            Text(
                              'TAP TO SCAN',
                              style: CyberpunkText.pixelHeading(
                                fontSize: 16,
                                color: CyberpunkColors.neonGreen,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Take or choose a photo of your waste',
                              style: CyberpunkText.bodyText(
                                color: CyberpunkColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: CyberpunkColors.backgroundJungle,
                                border: Border.all(
                                  color: CyberpunkColors.electricLime,
                                  width: 1,
                                ),
                                borderRadius: BorderRadius.circular(2),
                              ),
                              child: Text(
                                '♻ AI-POWERED WASTE DETECTION',
                                style: CyberpunkText.pixelLabel(
                                  fontSize: 8,
                                  color: CyberpunkColors.electricLime,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          ),
          Positioned(
            left: 16,
            bottom: 24,
            child: Container(
              decoration: BoxDecoration(
                color: CyberpunkColors.backgroundJungle,
                borderRadius: BorderRadius.circular(2),
                border: Border.all(color: CyberpunkColors.neonGreen, width: 2),
                boxShadow: CyberpunkGlow.greenGlow(intensity: 0.3),
              ),
              child: IconButton(
                icon: const Icon(Icons.history, color: CyberpunkColors.neonGreen),
                onPressed: () => context.push('/scan-history'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CyberpunkListTile extends StatelessWidget {
  const _CyberpunkListTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: CyberpunkColors.backgroundJungle,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: CyberpunkColors.neonGreen, width: 1),
      ),
      child: ListTile(
        leading: Icon(icon, color: CyberpunkColors.neonGreen),
        title: Text(title, style: CyberpunkText.pixelLabel(fontSize: 10)),
        subtitle: Text(
          subtitle,
          style: CyberpunkText.bodyText(
            fontSize: 12,
            color: CyberpunkColors.textSecondary,
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}