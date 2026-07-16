import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:kitakitar_mobile/services/ai_service.dart';
import 'package:kitakitar_mobile/services/firestore_service.dart';
import 'package:kitakitar_mobile/services/storage_service.dart';
import 'package:kitakitar_mobile/providers/auth_provider.dart';
import 'package:kitakitar_mobile/theme/app_theme.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen>
    with TickerProviderStateMixin {
  final AIService _aiService = AIService();
  final FirestoreService _firestoreService = FirestoreService();
  final StorageService _storageService = StorageService();
  final ImagePicker _picker = ImagePicker();
  bool _isProcessing = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _floatController;
  late AnimationController _spinController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _floatController.dispose();
    _spinController.dispose();
    super.dispose();
  }

  void _showImageSourcePicker() {
    if (_isProcessing) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding:
              const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Choose how to add a photo',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 24),
              _SourceOption(
                icon: Icons.camera_alt_rounded,
                title: 'Take a photo',
                subtitle: 'Capture your waste with the camera',
                onTap: () {
                  Navigator.pop(context);
                  _pickAndProcessImage(ImageSource.camera);
                },
              ),
              const SizedBox(height: 8),
              _SourceOption(
                icon: Icons.photo_library_rounded,
                title: 'Choose from gallery',
                subtitle: 'Upload a photo from your gallery',
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

      setState(() => _isProcessing = true);

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
        setState(() => _isProcessing = false);
        context.push('/scan-result', extra: {
          'detectedMaterials': scanResult.materials,
          'preparationTip': scanResult.preparationTip,
          'imagePath': image.path,
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan')),
      body: Stack(
        children: [
          // Background
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(gradient: AppColors.scanGradient),
          ),

          // Floating decorative blobs
          ..._buildFloatingDecorations(),

          // Main content
          GestureDetector(
            onTap: _isProcessing ? null : _showImageSourcePicker,
            behavior: HitTestBehavior.translucent,
            child: SizedBox.expand(
              child: _isProcessing ? _buildProcessingState() : _buildIdleState(),
            ),
          ),

          // Scan history — top-left (above main tap area)
          Positioned(
            left: 12,
            top: 8,
            child: Material(
              elevation: 4,
              shadowColor: Colors.black26,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => context.push('/scan-history'),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.history_rounded,
                    color: AppColors.primary,
                    size: 24,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // -----------------------------------------------------------------------
  // Floating decorations — orbiting material icons + soft blobs
  // -----------------------------------------------------------------------
  List<Widget> _buildFloatingDecorations() {
    return [
      // Large soft circle top-right
      Positioned(
        top: -40,
        right: -50,
        child: Container(
          width: 180,
          height: 180,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primaryLight.withAlpha(18),
          ),
        ),
      ),
      // Small soft circle bottom-left
      Positioned(
        bottom: 60,
        left: -30,
        child: Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primary.withAlpha(12),
          ),
        ),
      ),

      // Orbiting icons live in the hero Stack (between SCAN button & tip cards)

      // Floating leaf accents
      _buildFloatingLeaf(
        alignment: const Alignment(0.85, -0.6),
        delay: 0.0,
        icon: '\uD83C\uDF3F', // 🌿
        size: 28,
      ),
      _buildFloatingLeaf(
        alignment: const Alignment(-0.8, -0.35),
        delay: 0.33,
        icon: '\u267B\uFE0F', // ♻️
        size: 24,
      ),
      _buildFloatingLeaf(
        alignment: const Alignment(0.7, 0.55),
        delay: 0.66,
        icon: '\uD83C\uDF0D', // 🌍
        size: 26,
      ),
    ];
  }

  /// Orbit confined to [boxWidth] x [boxHeight] (hero zone — between tips & SCAN).
  List<Widget> _buildOrbitingIcons(double boxWidth, double boxHeight) {
    const orbitIcons = [
      (Icons.newspaper_rounded, 'Paper'),
      (Icons.local_drink_rounded, 'Plastic'),
      (Icons.wine_bar_rounded, 'Glass'),
      (Icons.battery_charging_full_rounded, 'Battery'),
      (Icons.devices_rounded, 'E-Waste'),
      (Icons.delete_rounded, 'Metal'),
    ];

    const halfIcon = 22.0;
    final centerX = boxWidth / 2;
    final centerY = boxHeight / 2;
    final rx = (boxWidth * 0.44).clamp(60.0, boxWidth / 2 - halfIcon - 4);
    final ry = (boxHeight * 0.36).clamp(50.0, boxHeight / 2 - halfIcon - 4);

    return List.generate(orbitIcons.length, (i) {
      final fraction = i / orbitIcons.length;
      final entry = orbitIcons[i];

      return AnimatedBuilder(
        animation: _spinController,
        builder: (context, child) {
          final angle =
              (_spinController.value + fraction) * 2 * math.pi;
          final x = centerX + rx * math.cos(angle) - halfIcon;
          final y = centerY + ry * math.sin(angle) - halfIcon;
          final scale = 0.6 + 0.4 * ((math.sin(angle) + 1) / 2);
          final opacity = 0.25 + 0.35 * ((math.sin(angle) + 1) / 2);

          return Positioned(
            left: x,
            top: y,
            child: Opacity(
              opacity: opacity,
              child: Transform.scale(
                scale: scale,
                child: child,
              ),
            ),
          );
        },
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withAlpha(20),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(entry.$1, size: 20, color: AppColors.primary),
              Text(
                entry.$2,
                style: const TextStyle(fontSize: 6, color: AppColors.primary),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildFloatingLeaf({
    required Alignment alignment,
    required double delay,
    required String icon,
    required double size,
  }) {
    return AnimatedBuilder(
      animation: _floatController,
      builder: (context, child) {
        final t =
            ((_floatController.value + delay) % 1.0) * 2 * math.pi;
        final dy = math.sin(t) * 10;
        return Align(
          alignment: alignment,
          child: Transform.translate(
            offset: Offset(0, dy),
            child: child,
          ),
        );
      },
      child: Text(icon, style: TextStyle(fontSize: size)),
    );
  }

  // -----------------------------------------------------------------------
  // Idle state — CTA + tips
  // -----------------------------------------------------------------------
  Widget _buildIdleState() {
    const double heroH = 300;

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Space so content clears the history FAB in the parent Stack
          const SizedBox(height: 44),

          const Spacer(flex: 2),

          // Hero: orbit icons (behind) + pulsing SCAN — stays above tip cards
          LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              return SizedBox(
                height: heroH,
                width: w,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    ..._buildOrbitingIcons(w, heroH),
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _pulseAnimation.value,
                          child: child,
                        );
                      },
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 170,
                            height: 170,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withAlpha(20),
                              shape: BoxShape.circle,
                            ),
                          ),
                          Container(
                            width: 146,
                            height: 146,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withAlpha(32),
                              shape: BoxShape.circle,
                            ),
                          ),
                          Container(
                            width: 130,
                            height: 130,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [Color(0xFF43A047), Color(0xFF2E7D32)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withAlpha(60),
                                  blurRadius: 28,
                                  spreadRadius: 4,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.camera_alt_rounded,
                                    size: 44, color: Colors.white),
                                SizedBox(height: 4),
                                Text(
                                  'SCAN',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 24),

          const Text(
            'Tap to identify waste',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Our AI recognizes recyclable materials instantly',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),

          const Spacer(flex: 1),

          // Tips row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(child: _TipCard(
                  emoji: '\uD83D\uDCF8', // 📸
                  title: 'Clear photo',
                  subtitle: 'Good lighting helps',
                )),
                const SizedBox(width: 10),
                Expanded(child: _TipCard(
                  emoji: '\uD83D\uDD0D', // 🔍
                  title: 'One item',
                  subtitle: 'Focus on one object',
                )),
                const SizedBox(width: 10),
                Expanded(child: _TipCard(
                  emoji: '\u2728', // ✨
                  title: 'AI magic',
                  subtitle: 'We do the rest',
                )),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Fun fact banner
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(200),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.primaryLight.withAlpha(40)),
              ),
              child: Row(
                children: [
                  const Text('\uD83C\uDF31', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700, height: 1.4),
                        children: const [
                          TextSpan(text: 'Recycling '),
                          TextSpan(
                            text: '1 plastic bottle',
                            style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                          ),
                          TextSpan(text: ' saves enough energy to power a laptop for '),
                          TextSpan(
                            text: '25 minutes',
                            style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                          ),
                          TextSpan(text: '!'),
                        ],
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

  // -----------------------------------------------------------------------
  // Processing state
  // -----------------------------------------------------------------------
  Widget _buildProcessingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 100,
                height: 100,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: AppColors.primary,
                  backgroundColor: AppColors.primary.withAlpha(20),
                ),
              ),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withAlpha(25),
                      blurRadius: 16,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  size: 32,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          const Text(
            'Analyzing...',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'AI is identifying recyclable materials',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------------------
// Tip card
// -------------------------------------------------------------------------

class _TipCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;

  const _TipCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(210),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withAlpha(180)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 6),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------------------
// Source option (bottom sheet)
// -------------------------------------------------------------------------

class _SourceOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SourceOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight.withAlpha(25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.primary, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}
