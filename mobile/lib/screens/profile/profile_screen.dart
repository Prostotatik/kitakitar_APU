import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:kitakitar_mobile/providers/auth_provider.dart';
import 'package:kitakitar_mobile/providers/user_provider.dart';
import 'package:kitakitar_mobile/services/storage_service.dart';
import 'package:kitakitar_mobile/theme/cyberpunk_theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final StorageService _storageService = StorageService();
  bool _isEditing = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );

    if (image == null) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.user?.uid;
    if (userId == null) return;

    try {
      final imageUrl = await _storageService.uploadImage(
        image,
        userId,
      );

      final userProvider = Provider.of<UserProvider>(context, listen: false);
      await userProvider.updateProfile(avatarUrl: imageUrl);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('UPLOAD ERROR: $e', style: CyberpunkText.bodyText()),
            backgroundColor: CyberpunkColors.backgroundMoss,
          ),
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    await userProvider.updateProfile(
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
    );

    setState(() {
      _isEditing = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PROFILE UPDATED', style: CyberpunkText.bodyText()),
          backgroundColor: CyberpunkColors.backgroundMoss,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final user = userProvider.user;

    if (user == null) {
      return Scaffold(
        backgroundColor: CyberpunkColors.backgroundDeep,
        body: const Center(
          child: CircularProgressIndicator(color: CyberpunkColors.neonGreen),
        ),
      );
    }

    if (!_isEditing &&
        (_nameController.text != user.name ||
            _emailController.text != user.email)) {
      _nameController.text = user.name;
      _emailController.text = user.email;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('PROFILE', style: CyberpunkText.pixelHeading(fontSize: 12)),
        backgroundColor: CyberpunkColors.backgroundDeep,
        elevation: 0,
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit, color: CyberpunkColors.neonGreen),
              onPressed: () {
                setState(() {
                  _isEditing = true;
                });
              },
            )
          else
            IconButton(
              icon: const Icon(Icons.check, color: CyberpunkColors.neonGreen),
              onPressed: _saveProfile,
            ),
        ],
      ),
      body: CircuitGridBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const SizedBox(height: 24),
                // Avatar with neon border
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: CyberpunkColors.neonGreen,
                          width: 3,
                        ),
                        boxShadow: CyberpunkGlow.greenGlow(
                          intensity: _pulseAnimation.value * 0.5,
                        ),
                      ),
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 66,
                            backgroundColor: CyberpunkColors.backgroundJungle,
                            backgroundImage: user.avatarUrl != null
                                ? NetworkImage(user.avatarUrl!)
                                : null,
                            child: user.avatarUrl == null
                                ? const Icon(
                                    Icons.person,
                                    size: 60,
                                    color: CyberpunkColors.neonGreen,
                                  )
                                : null,
                          ),
                          if (_isEditing)
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: CyberpunkColors.neonGreen,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: CyberpunkColors.electricLime,
                                    width: 2,
                                  ),
                                ),
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.camera_alt,
                                    size: 20,
                                    color: CyberpunkColors.backgroundDeep,
                                  ),
                                  onPressed: _pickImage,
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 32),
                // Name Field
                Text(
                  'NAME',
                  style: CyberpunkText.pixelLabel(
                    fontSize: 8,
                    color: CyberpunkColors.electricLime,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _nameController,
                  enabled: _isEditing,
                  style: CyberpunkText.bodyText(),
                  decoration: InputDecoration(
                    hintText: 'Your Name',
                    hintStyle: CyberpunkText.bodyText(
                      color: CyberpunkColors.textSecondary.withOpacity(0.5),
                    ),
                    prefixIcon: const Icon(Icons.person, color: CyberpunkColors.neonGreen),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'ENTER NAME';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                // Email Field
                Text(
                  'EMAIL',
                  style: CyberpunkText.pixelLabel(
                    fontSize: 8,
                    color: CyberpunkColors.electricLime,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _emailController,
                  enabled: _isEditing,
                  keyboardType: TextInputType.emailAddress,
                  style: CyberpunkText.bodyText(),
                  decoration: InputDecoration(
                    hintText: 'user@example.com',
                    hintStyle: CyberpunkText.bodyText(
                      color: CyberpunkColors.textSecondary.withOpacity(0.5),
                    ),
                    prefixIcon: const Icon(Icons.email, color: CyberpunkColors.neonGreen),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'ENTER EMAIL';
                    }
                    if (!value.contains('@')) {
                      return 'ENTER VALID EMAIL';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 32),
                // Stats Card
                CyberpunkCard(
                  borderColor: CyberpunkColors.electricLime,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.stars,
                                color: CyberpunkColors.electricLime,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'ECO CREDITS',
                                style: CyberpunkText.pixelLabel(fontSize: 8),
                              ),
                            ],
                          ),
                          Text(
                            '${user.points}',
                            style: CyberpunkText.pixelHeading(
                              fontSize: 18,
                              color: CyberpunkColors.electricLime,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 12),
                        height: 1,
                        color: CyberpunkColors.amberMoss,
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.scale,
                                color: CyberpunkColors.neonGreen,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'TOTAL WEIGHT',
                                style: CyberpunkText.pixelLabel(fontSize: 8),
                              ),
                            ],
                          ),
                          Text(
                            '${user.totalWeight.toStringAsFixed(2)} KG',
                            style: CyberpunkText.pixelHeading(
                              fontSize: 14,
                              color: CyberpunkColors.neonGreen,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                NeonButton(
                  label: 'SCAN QR CODE',
                  onPressed: () => context.push('/qr-scanner'),
                  icon: Icons.qr_code_scanner,
                ),
                const SizedBox(height: 16),
                NeonButton(
                  label: 'SIGN OUT',
                  onPressed: () => authProvider.signOut(),
                  glowColor: CyberpunkColors.warningGlow,
                  isPrimary: false,
                  icon: Icons.logout,
                ),
                const SizedBox(height: 24),
                const ArcadeHudBar(
                  leftText: '♻ ECO SYS',
                  centerText: 'LEVEL 1',
                  rightText: 'SAVE PLANET © 2077',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}