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

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final StorageService _storageService = StorageService();
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
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
          SnackBar(content: Text('Upload error: $e')),
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
        const SnackBar(content: Text('PROFILE UPDATED')),
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
        backgroundColor: CyberpunkColors.voidBlack,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(CyberpunkColors.neonGreen),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'LOADING...',
                style: TextStyle(
                  color: CyberpunkColors.neonGreen,
                  fontSize: 10,
                  fontFamily: 'PressStart2P',
                ),
              ),
            ],
          ),
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
      backgroundColor: CyberpunkColors.voidBlack,
      appBar: AppBar(
        backgroundColor: CyberpunkColors.voidBlack,
        elevation: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person, color: CyberpunkColors.neonGreen, size: 24),
            const SizedBox(width: 12),
            Text(
              'PROFILE',
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
          if (!_isEditing)
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border: Border.all(color: CyberpunkColors.neonGreen.withOpacity(0.5), width: 1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.edit, color: CyberpunkColors.neonGreen, size: 18),
              ),
              onPressed: () {
                setState(() {
                  _isEditing = true;
                });
              },
            )
          else
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: CyberpunkColors.neonGreen,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.check, color: CyberpunkColors.voidBlack, size: 18),
              ),
              onPressed: _saveProfile,
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
      body: Container(
        decoration: const BoxDecoration(color: CyberpunkColors.voidBlack),
        child: Stack(
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
            SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    const SizedBox(height: 24),
                    // Avatar
                    Stack(
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: CyberpunkColors.darkMatter,
                            border: Border.all(color: CyberpunkColors.neonGreen, width: 3),
                            borderRadius: BorderRadius.circular(60),
                            boxShadow: NeonGlow.greenGlow(blur: 20),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(58),
                            child: user.avatarUrl != null
                                ? Image.network(
                                    user.avatarUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => Icon(
                                      Icons.person,
                                      size: 60,
                                      color: CyberpunkColors.neonGreen,
                                    ),
                                  )
                                : Icon(
                                    Icons.person,
                                    size: 60,
                                    color: CyberpunkColors.neonGreen,
                                  ),
                          ),
                        ),
                        if (_isEditing)
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: _pickImage,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: CyberpunkColors.neonGreen,
                                  border: Border.all(color: CyberpunkColors.voidBlack, width: 2),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: NeonGlow.greenGlow(blur: 8),
                                ),
                                child: const Icon(
                                  Icons.camera_alt,
                                  size: 20,
                                  color: CyberpunkColors.voidBlack,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    // Name field
                    NeonTextField(
                      controller: _nameController,
                      labelText: 'NAME',
                      hintText: 'Your identity',
                      prefixIcon: Icons.person,
                      enabled: _isEditing,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Enter name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    // Email field
                    NeonTextField(
                      controller: _emailController,
                      labelText: 'EMAIL',
                      hintText: 'user@example.com',
                      prefixIcon: Icons.email,
                      keyboardType: TextInputType.emailAddress,
                      enabled: _isEditing,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Enter email';
                        }
                        if (!value.contains('@')) {
                          return 'Enter a valid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 32),
                    // Stats card
                    ArcadeCard(
                      neonColor: CyberpunkColors.amber,
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.eco, color: CyberpunkColors.amber, size: 20),
                                  const SizedBox(width: 12),
                                  Text(
                                    'ECO CREDITS',
                                    style: TextStyle(
                                      color: CyberpunkColors.mistGray,
                                      fontSize: 10,
                                      fontFamily: 'PressStart2P',
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                '${user.points}',
                                style: TextStyle(
                                  color: CyberpunkColors.amber,
                                  fontSize: 20,
                                  fontFamily: 'PressStart2P',
                                  fontWeight: FontWeight.w700,
                                  shadows: NeonGlow.amberTextGlow(),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Container(
                            height: 1,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.transparent,
                                  CyberpunkColors.amber.withOpacity(0.5),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.scale, color: CyberpunkColors.neonCyan, size: 20),
                                  const SizedBox(width: 12),
                                  Text(
                                    'TOTAL WEIGHT',
                                    style: TextStyle(
                                      color: CyberpunkColors.mistGray,
                                      fontSize: 10,
                                      fontFamily: 'PressStart2P',
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                '${user.totalWeight.toStringAsFixed(2)} KG',
                                style: TextStyle(
                                  color: CyberpunkColors.neonCyan,
                                  fontSize: 20,
                                  fontFamily: 'PressStart2P',
                                  fontWeight: FontWeight.w700,
                                  shadows: NeonGlow.cyanTextGlow(),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // QR Scanner button
                    PixelButton(
                      text: 'SCAN QR CODE',
                      neonColor: CyberpunkColors.neonCyan,
                      icon: Icons.qr_code_scanner,
                      onPressed: () => context.push('/qr-scanner'),
                    ),
                    const SizedBox(height: 16),
                    // Sign out button
                    PixelButton(
                      text: 'SIGN OUT',
                      neonColor: CyberpunkColors.warningRed,
                      isOutlined: true,
                      onPressed: () {
                        authProvider.signOut();
                      },
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}