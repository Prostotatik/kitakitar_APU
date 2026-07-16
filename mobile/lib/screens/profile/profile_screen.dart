import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:kitakitar_mobile/providers/auth_provider.dart';
import 'package:kitakitar_mobile/providers/user_provider.dart';
import 'package:kitakitar_mobile/services/storage_service.dart';
import 'package:kitakitar_mobile/theme/app_theme.dart';

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
  late AnimationController _qrPulse;

  @override
  void initState() {
    super.initState();
    _qrPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _qrPulse.dispose();
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
      final imageUrl = await _storageService.uploadImage(image, userId);
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

    setState(() => _isEditing = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated')),
      );
    }
  }

  void _showMenu() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final RenderBox button = context.findRenderObject() as RenderBox;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final topRight =
        Offset(button.size.width - 16, MediaQuery.of(context).padding.top + 12);

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        topRight.dx - 160,
        topRight.dy + 40,
        topRight.dx,
        overlay.size.height,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 8,
      items: [
        PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit_outlined,
                  size: 20, color: AppColors.textSecondary),
              const SizedBox(width: 12),
              const Text('Edit Profile'),
            ],
          ),
        ),
        const PopupMenuDivider(height: 1),
        PopupMenuItem(
          value: 'signout',
          child: Row(
            children: [
              Icon(Icons.logout, size: 20, color: Colors.red.shade400),
              const SizedBox(width: 12),
              Text('Sign Out',
                  style: TextStyle(color: Colors.red.shade400)),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == 'edit') {
        setState(() => _isEditing = true);
      } else if (value == 'signout') {
        authProvider.signOut();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final user = userProvider.user;

    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_isEditing &&
        (_nameController.text != user.name ||
            _emailController.text != user.email)) {
      _nameController.text = user.name;
      _emailController.text = user.email;
    }

    return Scaffold(
      body: Form(
        key: _formKey,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildProfileHeader(user)),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
              sliver: SliverToBoxAdapter(
                child: Column(
                  children: [
                    _buildStatsRow(user),
                    const SizedBox(height: 16),
                    _buildMemberSince(user),
                    const SizedBox(height: 20),
                    _buildQrButton(context),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(dynamic user) {
    return Stack(
      children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 12,
            bottom: 28,
          ),
          decoration: const BoxDecoration(
            gradient: AppColors.heroGradient,
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(32),
              bottomRight: Radius.circular(32),
            ),
          ),
          child: Column(
            children: [
              // Top bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (_isEditing)
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70),
                        onPressed: () => setState(() => _isEditing = false),
                      )
                    else
                      const SizedBox(width: 48),
                    const Text(
                      'Profile',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    if (_isEditing)
                      IconButton(
                        icon: const Icon(Icons.check_rounded,
                            color: Colors.white),
                        onPressed: _saveProfile,
                      )
                    else
                      IconButton(
                        icon: const Icon(Icons.more_vert_rounded,
                            color: Colors.white),
                        onPressed: _showMenu,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Avatar with decorative ring
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 124,
                    height: 124,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withAlpha(20),
                        width: 2,
                      ),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withAlpha(60),
                        width: 3,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 52,
                      backgroundColor: Colors.white.withAlpha(30),
                      backgroundImage: user.avatarUrl != null
                          ? NetworkImage(user.avatarUrl!)
                          : null,
                      child: user.avatarUrl == null
                          ? const Icon(Icons.person,
                              size: 48, color: Colors.white70)
                          : null,
                    ),
                  ),
                  if (_isEditing)
                    Positioned(
                      bottom: 2,
                      right: 2,
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(30),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                          child: const Icon(Icons.camera_alt,
                              size: 18, color: AppColors.primary),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),

              // Name
              if (_isEditing)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 48),
                  child: TextFormField(
                    controller: _nameController,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      filled: true,
                      fillColor: Colors.white.withAlpha(25),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: Colors.white.withAlpha(60)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: Colors.white.withAlpha(60)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: Colors.white, width: 1.5),
                      ),
                      hintText: 'Name',
                      hintStyle:
                          TextStyle(color: Colors.white.withAlpha(100)),
                    ),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Enter name' : null,
                  ),
                )
              else
                Text(
                  user.name,
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
              const SizedBox(height: 6),

              // Email
              if (_isEditing)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 48),
                  child: TextFormField(
                    controller: _emailController,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.emailAddress,
                    style: TextStyle(
                        fontSize: 14, color: Colors.white.withAlpha(200)),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      filled: true,
                      fillColor: Colors.white.withAlpha(18),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: Colors.white.withAlpha(40)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: Colors.white.withAlpha(40)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: Colors.white, width: 1.5),
                      ),
                      hintText: 'Email',
                      hintStyle:
                          TextStyle(color: Colors.white.withAlpha(80)),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Enter email';
                      if (!v.contains('@')) return 'Enter a valid email';
                      return null;
                    },
                  ),
                )
              else
                Text(
                  user.email,
                  style:
                      TextStyle(fontSize: 14, color: Colors.white.withAlpha(180)),
                ),
            ],
          ),
        ),

        // Decorative blobs inside the header
        Positioned(
          top: -30,
          right: -40,
          child: IgnorePointer(
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withAlpha(10),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: -20,
          left: -30,
          child: IgnorePointer(
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withAlpha(8),
              ),
            ),
          ),
        ),
        Positioned(
          top: 60,
          left: 20,
          child: IgnorePointer(
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withAlpha(25),
              ),
            ),
          ),
        ),
        Positioned(
          top: 90,
          right: 30,
          child: IgnorePointer(
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withAlpha(30),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow(dynamic user) {
    final double co2 = user.carbonFootprint;
    final double trees = co2 / 22.0;

    return Column(
      children: [
        // CO₂ stat with gradient accent
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFE8F5E9), Color(0xFFC8E6C9)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primaryLight.withAlpha(60)),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withAlpha(15),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2E7D32), Color(0xFF4CAF50)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.eco_rounded,
                    color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${co2.toStringAsFixed(2)} kg',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'CO\u2082 Prevented',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.primary),
                    ),
                  ],
                ),
              ),
              if (trees >= 0.1)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(200),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('\uD83C\uDF33',
                          style: TextStyle(fontSize: 14)),
                      const SizedBox(width: 4),
                      Text(
                        '${trees.toStringAsFixed(1)}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _TreeFactBanner(co2: co2, trees: trees),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.stars_rounded,
                iconColor: const Color(0xFFFFC107),
                label: 'Kitar Points',
                value: '${user.points}',
                accentGradient: const [Color(0xFFF1F8E9), Color(0xFFDCEDC8)],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.scale_rounded,
                iconColor: AppColors.primary,
                label: 'Total Weight',
                value: '${user.totalWeight.toStringAsFixed(1)} kg',
                accentGradient: const [Color(0xFFE8F5E9), Color(0xFFC8E6C9)],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMemberSince(dynamic user) {
    final months = DateTime.now().difference(user.createdAt).inDays ~/ 30;
    final label = months < 1
        ? 'New member'
        : months < 12
            ? '$months month${months == 1 ? '' : 's'}'
            : '${months ~/ 12} year${months ~/ 12 == 1 ? '' : 's'}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.primaryLight.withAlpha(20),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.calendar_month_rounded,
                color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Member for $label',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                'Joined ${_formatDate(user.createdAt)}',
                style:
                    TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.verified_rounded,
                    size: 14, color: AppColors.primary),
                const SizedBox(width: 4),
                Text(
                  'Active',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  Widget _buildQrButton(BuildContext context) {
    return AnimatedBuilder(
      animation: _qrPulse,
      builder: (context, child) {
        final glowOpacity = 0.18 + _qrPulse.value * 0.22;
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color:
                    AppColors.primary.withAlpha((glowOpacity * 255).round()),
                blurRadius: 24,
                spreadRadius: 2,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: child,
        );
      },
      child: Material(
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push('/qr-scanner'),
          child: Ink(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF1B5E20),
                  Color(0xFF43A047),
                  Color(0xFF66BB6A)
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Stack(
              children: [
                // Decorative circles inside button
                Positioned(
                  right: -20,
                  top: -20,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withAlpha(12),
                    ),
                  ),
                ),
                Positioned(
                  left: -10,
                  bottom: -15,
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withAlpha(8),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      vertical: 22, horizontal: 24),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(35),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.qr_code_scanner_rounded,
                            color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 16),
                      const Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Scan QR Code',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.3,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'Claim your Kitar Points at a recycling center',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.arrow_forward_ios_rounded,
                          color: Colors.white.withAlpha(180), size: 18),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Stat card
// ---------------------------------------------------------------------------

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final List<Color>? accentGradient;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.accentGradient,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        gradient: accentGradient != null
            ? LinearGradient(
                colors: accentGradient!,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: accentGradient == null ? Colors.white : null,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryLight.withAlpha(30)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withAlpha(10),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: iconColor.withAlpha(30),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style:
                      TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tree fact banner
// ---------------------------------------------------------------------------

class _TreeFactBanner extends StatelessWidget {
  final double co2;
  final double trees;

  const _TreeFactBanner({required this.co2, required this.trees});

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF2E7D32);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F8E9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFC5E1A5)),
      ),
      child: Row(
        children: [
          const Text('\uD83C\uDF33', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: TextStyle(
                    fontSize: 12, color: Colors.grey.shade700, height: 1.4),
                children: [
                  const TextSpan(text: 'Did you know that '),
                  const TextSpan(
                    text: '22 kg',
                    style:
                        TextStyle(color: green, fontWeight: FontWeight.bold),
                  ),
                  const TextSpan(text: ' of prevented CO'),
                  const TextSpan(
                    text: '\u2082',
                    style:
                        TextStyle(color: green, fontWeight: FontWeight.bold),
                  ),
                  const TextSpan(text: ' equals '),
                  const TextSpan(
                    text: '1 tree',
                    style:
                        TextStyle(color: green, fontWeight: FontWeight.bold),
                  ),
                  const TextSpan(text: ' planted? '),
                  if (co2 > 0) ...[
                    const TextSpan(text: "You've saved "),
                    TextSpan(
                      text: '\uD83C\uDF33 ${trees.toStringAsFixed(1)} trees',
                      style: const TextStyle(
                          color: green, fontWeight: FontWeight.bold),
                    ),
                    const TextSpan(text: ' so far!'),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
