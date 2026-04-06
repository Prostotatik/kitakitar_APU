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
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
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
      backgroundColor: CyberpunkColors.darkMatter,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        side: BorderSide(color: CyberpunkColors.neonGreen, width: 2),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'SELECT INPUT METHOD',
                style: TextStyle(
                  color: CyberpunkColors.neonGreen,
                  fontSize: 12,
                  fontFamily: 'PressStart2P',
                  shadows: NeonGlow.greenTextGlow(),
                ),
              ),
              const SizedBox(height: 24),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: CyberpunkColors.neonGreen.withOpacity(0.1),
                    border: Border.all(color: CyberpunkColors.neonGreen, width: 1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.camera_alt, color: CyberpunkColors.neonGreen),
                ),
                title: Text(
                  'CAMERA',
                  style: TextStyle(
                    color: CyberpunkColors.pureWhite,
                    fontSize: 12,
                    fontFamily: 'PressStart2P',
                  ),
                ),
                subtitle: Text(
                  'Capture waste with camera',
                  style: TextStyle(
                    color: CyberpunkColors.mistGray,
                    fontFamily: 'RobotoMono',
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndProcessImage(ImageSource.camera);
                },
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: CyberpunkColors.neonCyan.withOpacity(0.1),
                    border: Border.all(color: CyberpunkColors.neonCyan, width: 1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.photo_library, color: CyberpunkColors.neonCyan),
                ),
                title: Text(
                  'GALLERY',
                  style: TextStyle(
                    color: CyberpunkColors.pureWhite,
                    fontSize: 12,
                    fontFamily: 'PressStart2P',
                  ),
                ),
                subtitle: Text(
                  'Upload photo from gallery',
                  style: TextStyle(
                    color: CyberpunkColors.mistGray,
                    fontFamily: 'RobotoMono',
                  ),
                ),
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

      // Upload image to storage
      final imageUrl = await _storageService.uploadImage(
        File(image.path),
        userId,
      );

      // Detect materials with AI
      final scanResult = await _aiService.detectMaterials(image.path);

      // Save AI scan to Firestore
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

        // Navigate to result screen
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
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CyberpunkColors.voidBlack,
      appBar: AppBar(
        backgroundColor: CyberpunkColors.voidBlack,
        elevation: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.recycling, color: CyberpunkColors.neonGreen, size: 24),
            const SizedBox(width: 12),
            Text(
              'WASTE SCANNER',
              style: TextStyle(
                color: CyberpunkColors.neonGreen,
                fontSize: 12,
                fontFamily: 'PressStart2P',
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
                shadows: NeonGlow.greenTextGlow(),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border.all(color: CyberpunkColors.neonGreen.withOpacity(0.5), width: 1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.history, color: CyberpunkColors.neonGreen, size: 20),
            ),
            onPressed: () => context.push('/scan-history'),
          ),
        ],
        flexibleSpace: Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: CyberpunkColors.neonGreen.withOpacity(0.3), width: 1),
            ),
            boxShadow: [
              BoxShadow(
                color: CyberpunkColors.neonGreen.withOpacity(0.1),
                blurRadius: 20,
              ),
            ],
          ),
        ),
      ),
      body: Stack(
        children: [
          // Circuit grid background
          CustomPaint(
            painter: CircuitGridPainter(
              color: CyberpunkColors.neonGreen,
              gridSize: 50,
            ),
            size: Size.infinite,
          ),
          // Main content
          GestureDetector(
            onTap: _isProcessing ? null : _showImageSourcePicker,
            child: Container(
              width: double.infinity,
              height: double.infinity,
              color: Colors.transparent,
              child: _isProcessing
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(32),
                            decoration: BoxDecoration(
                              color: CyberpunkColors.darkMatter,
                              border: Border.all(color: CyberpunkColors.neonGreen, width: 2),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: NeonGlow.greenGlow(blur: 20),
                            ),
                            child: Column(
                              children: [
                                const SizedBox(
                                  width: 48,
                                  height: 48,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 3,
                                    valueColor: AlwaysStoppedAnimation(CyberpunkColors.neonGreen),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  'ANALYZING...',
                                  style: TextStyle(
                                    color: CyberpunkColors.neonGreen,
                                    fontSize: 12,
                                    fontFamily: 'PressStart2P',
                                    shadows: NeonGlow.greenTextGlow(),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'AI processing your waste',
                                  style: TextStyle(
                                    color: CyberpunkColors.mistGray,
                                    fontSize: 10,
                                    fontFamily: 'RobotoMono',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Animated scanner icon
                          AnimatedBuilder(
                            animation: _pulseAnimation,
                            builder: (context, child) {
                              return Container(
                                width: 160,
                                height: 160,
                                decoration: BoxDecoration(
                                  color: CyberpunkColors.darkMatter,
                                  border: Border.all(
                                    color: CyberpunkColors.neonGreen,
                                    width: 3,
                                  ),
                                  borderRadius: BorderRadius.circular(32),
                                  boxShadow: [
                                    BoxShadow(
                                      color: CyberpunkColors.neonGreen.withOpacity(_pulseAnimation.value * 0.6),
                                      blurRadius: 30,
                                      spreadRadius: 5,
                                    ),
                                    BoxShadow(
                                      color: CyberpunkColors.neonGreen.withOpacity(_pulseAnimation.value * 0.3),
                                      blurRadius: 60,
                                      spreadRadius: 10,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.camera_alt,
                                  size: 72,
                                  color: CyberpunkColors.neonGreen,
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 48),
                          Text(
                            'TAP TO SCAN',
                            style: TextStyle(
                              color: CyberpunkColors.neonGreen,
                              fontSize: 18,
                              fontFamily: 'PressStart2P',
                              fontWeight: FontWeight.w700,
                              letterSpacing: 3,
                              shadows: NeonGlow.greenTextGlow(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Take or choose a photo of your waste',
                            style: TextStyle(
                              color: CyberpunkColors.mistGray,
                              fontSize: 12,
                              fontFamily: 'RobotoMono',
                            ),
                          ),
                          const SizedBox(height: 48),
                          // Info cards
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildInfoCard(Icons.eco, 'RECYCLE', 'Save planet'),
                                _buildInfoCard(Icons.star, 'EARN', 'Get credits'),
                                _buildInfoCard(Icons.location_on, 'FIND', 'Nearby centers'),
                              ],
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

  Widget _buildInfoCard(IconData icon, String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CyberpunkColors.darkMatter,
        border: Border.all(color: CyberpunkColors.neonGreen.withOpacity(0.3), width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: CyberpunkColors.neonGreen, size: 24),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              color: CyberpunkColors.neonGreen,
              fontSize: 8,
              fontFamily: 'PressStart2P',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              color: CyberpunkColors.mistGray,
              fontSize: 10,
              fontFamily: 'RobotoMono',
            ),
          ),
        ],
      ),
    );
  }
}