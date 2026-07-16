import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

import 'package:qr_flutter/qr_flutter.dart';

import 'firebase_options.dart';
import 'models/center_material.dart' show CenterMaterialEntry, getMaterialIcon, kMaterialTypes;
import 'models/center_profile.dart';
import 'providers/center_auth_provider.dart';
import 'providers/center_data_provider.dart';
import 'services/center_firestore_service.dart';
import 'widgets/address_map_picker.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const CenterWebApp());
}

class CenterWebApp extends StatelessWidget {
  const CenterWebApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CenterAuthProvider()),
        ChangeNotifierProvider(create: (_) => CenterDataProvider()),
      ],
      child: MaterialApp(
        title: 'KitaKitar Center',
        debugShowCheckedModeBanner: false,
        theme: _buildTheme(Brightness.light),
        darkTheme: _buildTheme(Brightness.dark),
        home: const _RootShell(),
      ),
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    // Match mobile app branding: green primary (0xFF4CAF50).
    const primary = Color(0xFF4CAF50);
    const secondary = Color(0xFF2E7D32);
    const surfaceLight = Color(0xFFF8FAFC);
    const onSurfaceLight = Color(0xFF1E293B);

    final isLight = brightness == Brightness.light;
    final base = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary: primary,
        secondary: secondary,
        brightness: brightness,
        surface: isLight ? surfaceLight : const Color(0xFF1E293B),
        onSurface: isLight ? onSurfaceLight : const Color(0xFFF1F5F9),
      ),
      useMaterial3: true,
    );

    return base.copyWith(
      scaffoldBackgroundColor: isLight
          ? const Color(0xFFF0FDF4)
          : const Color(0xFF0F172A),
      colorScheme: base.colorScheme.copyWith(
        surface: isLight ? surfaceLight : const Color(0xFF1E293B),
        onSurface: isLight ? onSurfaceLight : const Color(0xFFF1F5F9),
      ),
      textTheme: base.textTheme.apply(
        fontFamily: 'Roboto',
        bodyColor: isLight ? onSurfaceLight : const Color(0xFFF1F5F9),
        displayColor: isLight ? onSurfaceLight : const Color(0xFFF1F5F9),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        filled: true,
        fillColor: isLight ? Colors.white : const Color(0xFF334155),
      ),
      cardTheme: CardThemeData(
        color: isLight ? Colors.white : const Color(0xFF1E293B),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
    );
  }
}

enum _AuthMode { login, register, forgot }
/// Root shell that switches between auth and dashboard, based on CenterAuthProvider.
class _RootShell extends StatefulWidget {
  const _RootShell();

  @override
  State<_RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<_RootShell> {
  _AuthMode _authMode = _AuthMode.login;

  void _switchAuthMode(_AuthMode mode) {
    setState(() {
      _authMode = mode;
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<CenterAuthProvider>(context);

    if (!auth.isAuthenticated) {
      switch (_authMode) {
        case _AuthMode.login:
          return LoginPage(
            onGoToRegister: () => _switchAuthMode(_AuthMode.register),
            onGoToForgot: () => _switchAuthMode(_AuthMode.forgot),
          );
        case _AuthMode.register:
          return RegisterCenterPage(
            onGoToLogin: () => _switchAuthMode(_AuthMode.login),
          );
        case _AuthMode.forgot:
          return ForgotPasswordPage(
            onBackToLogin: () => _switchAuthMode(_AuthMode.login),
          );
      }
    }

    return DashboardShell(
      centerId: auth.user!.uid,
      onLogout: () {
        auth.signOut();
        Provider.of<CenterDataProvider>(context, listen: false).clear();
      },
    );
  }
}

/// -----------------------
/// AUTH SCREENS
/// -----------------------

class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    required this.onGoToRegister,
    required this.onGoToForgot,
  });

  final VoidCallback onGoToRegister;
  final VoidCallback onGoToForgot;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter email and password')),
      );
      return;
    }

    final auth = Provider.of<CenterAuthProvider>(context, listen: false);
    final success = await auth.signInWithEmail(
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (!success && mounted && auth.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.error!)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = Provider.of<CenterAuthProvider>(context);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF4CAF50), Color(0xFF2E7D32), Color(0xFF1B5E20)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              elevation: 16,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(32),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _LogoHeader(
                      title: 'KitaKitar Center',
                      subtitle: 'Admin panel for recycling centers',
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Log in to your center',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    _EmailField(controller: _emailController),
                    const SizedBox(height: 12),
                    _PasswordField(
                      controller: _passwordController,
                      obscure: _obscurePassword,
                      onToggleObscure: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: auth.isLoading ? null : _handleLogin,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: auth.isLoading
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Sign in'),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: widget.onGoToForgot,
                      child: const Text('Forgot password?'),
                    ),
                    const Divider(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text("Don't have a center yet?"),
                        TextButton(
                          onPressed: widget.onGoToRegister,
                          child: const Text('Create account'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class RegisterCenterPage extends StatefulWidget {
  const RegisterCenterPage({
    super.key,
    required this.onGoToLogin,
  });

  final VoidCallback onGoToLogin;

  @override
  State<RegisterCenterPage> createState() => _RegisterCenterPageState();
}

class _RegisterCenterPageState extends State<RegisterCenterPage> {
  final _centerNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _managerNameController = TextEditingController();
  final _managerPhoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  double? _lat;
  double? _lng;
  bool _isSubmitting = false;
  /// type -> (minKg, maxKg, pricePerKg); only selected materials.
  final Map<String, ({double minKg, double maxKg, double pricePerKg})> _materials = {};

  @override
  void dispose() {
    _centerNameController.dispose();
    _addressController.dispose();
    _managerNameController.dispose();
    _managerPhoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _onLocationSelected(double lat, double lng, String address) {
    debugPrint(
      '[RegisterCenterPage] onLocationSelected lat=$lat, lng=$lng, address="$address"',
    );
    setState(() {
      _lat = lat;
      _lng = lng;
      _addressController.text = address;
    });
    debugPrint(
      '[RegisterCenterPage] state updated _lat=$_lat, _lng=$_lng, '
      'address="${_addressController.text}"',
    );
  }

  Future<void> _submit() async {
    final address = _addressController.text.trim();
    if (address.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select a point on the map and/or enter an address.'),
        ),
      );
      return;
    }
    if (_lat == null || _lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter an address (suggestions as you type) or tap on the map.'),
        ),
      );
      return;
    }
    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match')),
      );
      return;
    }
    final centerName = _centerNameController.text.trim();
    final managerName = _managerNameController.text.trim();
    final managerPhone = _managerPhoneController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (centerName.isEmpty || managerName.isEmpty || managerPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fill in center name and manager details.'),
        ),
      );
      return;
    }
    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter email and password for the center account.'),
        ),
      );
      return;
    }
    if (_materials.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select at least one accepted material type.'),
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final auth = Provider.of<CenterAuthProvider>(context, listen: false);
      final success = await auth.registerWithEmail(email, password);

      if (!success || auth.user == null) {
        setState(() {
          _isSubmitting = false;
        });
        if (auth.error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(auth.error!)),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to register the center.')),
          );
        }
        return;
      }

      final user = auth.user!;
      final firestore = CenterFirestoreService();

      final materialsList = _materials.entries.map((e) {
        final label = kMaterialTypes.firstWhere((t) => t['type'] == e.key)['label'] ?? e.key;
        return CenterMaterialEntry(
          type: e.key,
          label: label,
          minWeightKg: e.value.minKg,
          maxWeightKg: e.value.maxKg,
          pricePerKg: e.value.pricePerKg,
        );
      }).toList();

      await firestore.createCenter(
        centerId: user.uid,
        name: centerName,
        address: address,
        lat: _lat!,
        lng: _lng!,
        managerName: managerName,
        managerPhone: managerPhone,
        managerEmail: user.email ?? email,
        materials: materialsList,
      );

      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Center registered successfully.')),
      );
      // After successful registration auth.isAuthenticated is already true,
      // _RootShell will automatically navigate the user to the Dashboard.
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Registration error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF4CAF50), Color(0xFF2E7D32), Color(0xFF1B5E20)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: Card(
              elevation: 16,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(32),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const _LogoHeader(
                              title: 'Register center',
                              subtitle:
                                  'Join KitaKitar network and start accepting recyclable materials.',
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Why join?',
                              style: theme.textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            const _BulletPoint(
                              text:
                                  'Configure accepted materials, weight ranges and pricing.',
                            ),
                            const _BulletPoint(
                              text:
                                  'Generate one-time QR codes for every accepted load.',
                            ),
                            const _BulletPoint(
                              text:
                                  'Track statistics and points for your center in real time.',
                            ),
                          ],
                        ),
                      ),
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.only(left: 24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Center details',
                              style: theme.textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 12),
                            _LabeledTextField(
                              controller: _centerNameController,
                              label: 'Center name',
                              hint: 'Green Earth Recycling',
                            ),
                            const SizedBox(height: 16),
                            AddressMapPicker(
                              initialAddress: _addressController.text.isEmpty
                                  ? null
                                  : _addressController.text,
                              initialLat: _lat,
                              initialLng: _lng,
                              onLocationSelected: _onLocationSelected,
                              height: 220,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Manager',
                              style: theme.textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _LabeledTextField(
                                    controller: _managerNameController,
                                    label: 'Name',
                                    hint: 'John Smith',
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _LabeledTextField(
                                    controller: _managerPhoneController,
                                    label: 'Phone',
                                    hint: '+60 12-345 6789',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Accepted materials',
                              style: theme.textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Select types and set min/max weight (kg) and price per kg (0 = free).',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...kMaterialTypes.map((mat) {
                              final type = mat['type']!;
                              final label = mat['label']!;
                              final isSelected = _materials.containsKey(type);
                              final params = _materials[type] ?? (minKg: 0.5, maxKg: 100.0, pricePerKg: 0.0);
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _MaterialRow(
                                  icon: getMaterialIcon(type),
                                  label: label,
                                  selected: isSelected,
                                  minKg: isSelected ? params.minKg : 0.5,
                                  maxKg: isSelected ? params.maxKg : 100.0,
                                  pricePerKg: isSelected ? params.pricePerKg : 0.0,
                                  onChanged: (selected) {
                                    setState(() {
                                      if (selected) {
                                        _materials[type] = (minKg: 0.5, maxKg: 100.0, pricePerKg: 0.0);
                                      } else {
                                        _materials.remove(type);
                                      }
                                    });
                                  },
                                  onMinChanged: (v) {
                                    setState(() {
                                      final p = _materials[type]!;
                                      _materials[type] = (minKg: v, maxKg: p.maxKg, pricePerKg: p.pricePerKg);
                                    });
                                  },
                                  onMaxChanged: (v) {
                                    setState(() {
                                      final p = _materials[type]!;
                                      _materials[type] = (minKg: p.minKg, maxKg: v, pricePerKg: p.pricePerKg);
                                    });
                                  },
                                  onPriceChanged: (v) {
                                    setState(() {
                                      final p = _materials[type]!;
                                      _materials[type] = (minKg: p.minKg, maxKg: p.maxKg, pricePerKg: v);
                                    });
                                  },
                                ),
                              );
                            }),
                            const SizedBox(height: 16),
                            Text(
                              'Account',
                              style: theme.textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 12),
                            _LabeledTextField(
                              controller: _emailController,
                              label: 'Email',
                              hint: 'center@example.com',
                            ),
                            const SizedBox(height: 12),
                            _LabeledTextField(
                              controller: _passwordController,
                              label: 'Password',
                              hint: '••••••••',
                              obscure: true,
                            ),
                            const SizedBox(height: 12),
                            _LabeledTextField(
                              controller: _confirmPasswordController,
                              label: 'Confirm password',
                              hint: '••••••••',
                              obscure: true,
                            ),
                            const SizedBox(height: 20),
                            FilledButton(
                              onPressed: _isSubmitting ? null : _submit,
                              style: FilledButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Text('Create center account'),
                            ),
                            const SizedBox(height: 12),
                            TextButton(
                              onPressed: widget.onGoToLogin,
                              child: const Text('Already have account? Log in'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ForgotPasswordPage extends StatelessWidget {
  const ForgotPasswordPage({
    super.key,
    required this.onBackToLogin,
  });

  final VoidCallback onBackToLogin;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF4CAF50), Color(0xFF2E7D32), Color(0xFF1B5E20)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              elevation: 16,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(32),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _LogoHeader(
                      title: 'Reset password',
                      subtitle:
                          'Enter your email, we will send reset instructions.',
                    ),
                    const SizedBox(height: 24),
                    const _EmailField(),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'If an account exists, reset link will be sent.',
                            ),
                          ),
                        );
                      },
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text('Send reset link'),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: onBackToLogin,
                      child: const Text('Back to login'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// -----------------------
/// DASHBOARD SHELL
/// -----------------------

enum _DashboardPage { dashboard, profile, newIntake, qrCodes, history }

class DashboardShell extends StatefulWidget {
  const DashboardShell({super.key, required this.centerId, required this.onLogout});

  final String centerId;
  final VoidCallback onLogout;

  @override
  State<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends State<DashboardShell> {
  _DashboardPage _page = _DashboardPage.dashboard;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<CenterDataProvider>(context, listen: false).load(widget.centerId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          _Sidebar(
            current: _page,
            onSelect: (p) => setState(() => _page = p),
            onLogout: widget.onLogout,
          ),
          Expanded(
            child: Container(
              color: Theme.of(context).colorScheme.surface,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: _buildPage(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage() {
    switch (_page) {
      case _DashboardPage.dashboard:
        return _DashboardPageView(centerId: widget.centerId);
      case _DashboardPage.profile:
        return const _ProfilePageView();
      case _DashboardPage.newIntake:
        return const _NewIntakePageView();
      case _DashboardPage.qrCodes:
        return _QrCodesPageView(centerId: widget.centerId);
      case _DashboardPage.history:
        return _HistoryPageView(centerId: widget.centerId);
    }
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.current,
    required this.onSelect,
    required this.onLogout,
  });

  final _DashboardPage current;
  final ValueChanged<_DashboardPage> onSelect;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
                    ),
                  ),
                  child: const Icon(
                    Icons.loop_rounded,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'KitaKitar',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    Text(
                      'Center admin',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                _SidebarItem(
                  icon: Icons.space_dashboard_outlined,
                  label: 'Dashboard',
                  selected: current == _DashboardPage.dashboard,
                  onTap: () => onSelect(_DashboardPage.dashboard),
                ),
                _SidebarItem(
                  icon: Icons.storefront_outlined,
                  label: 'Center profile',
                  selected: current == _DashboardPage.profile,
                  onTap: () => onSelect(_DashboardPage.profile),
                ),
                _SidebarItem(
                  icon: Icons.add_circle_outline,
                  label: 'New intake',
                  selected: current == _DashboardPage.newIntake,
                  onTap: () => onSelect(_DashboardPage.newIntake),
                ),
                _SidebarItem(
                  icon: Icons.qr_code_2_outlined,
                  label: 'QR codes',
                  selected: current == _DashboardPage.qrCodes,
                  onTap: () => onSelect(_DashboardPage.qrCodes),
                ),
                _SidebarItem(
                  icon: Icons.history_rounded,
                  label: 'History',
                  selected: current == _DashboardPage.history,
                  onTap: () => onSelect(_DashboardPage.history),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: OutlinedButton.icon(
              onPressed: onLogout,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red.shade600,
                side: BorderSide(color: Colors.red.shade200),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Sign out'),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: selected
                ? colorScheme.primary.withOpacity(0.12)
                : Colors.transparent,
            border: Border(
              left: BorderSide(
                color: selected ? colorScheme.primary : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: selected ? colorScheme.primary : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color:
                      selected ? colorScheme.primary : colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// -----------------------
/// DASHBOARD PAGES (from Firestore)
/// -----------------------

class _DashboardPageView extends StatefulWidget {
  const _DashboardPageView({required this.centerId});

  final String centerId;

  @override
  State<_DashboardPageView> createState() => _DashboardPageViewState();
}

class _DashboardPageViewState extends State<_DashboardPageView> {
  List<TransactionListItem> _transactions = [];
  int _claimedQr = 0;
  bool _statsLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _statsLoading = true);
    final firestore = CenterFirestoreService();
    final results = await Future.wait([
      firestore.getTransactions(widget.centerId),
      firestore.getCompletedQrCodes(widget.centerId),
    ]);
    if (!mounted) return;
    setState(() {
      _transactions = results[0] as List<TransactionListItem>;
      _claimedQr = (results[1] as List).length;
      _statsLoading = false;
    });
  }

  /// Count intakes per day for the last [days] days.
  Map<DateTime, int> _dailyCounts({int days = 14}) {
    final now = DateTime.now();
    final startDay = DateTime(now.year, now.month, now.day).subtract(Duration(days: days - 1));
    final map = <DateTime, int>{};
    for (var i = 0; i < days; i++) {
      map[startDay.add(Duration(days: i))] = 0;
    }
    for (final t in _transactions) {
      if (t.createdAt == null) continue;
      final d = DateTime(t.createdAt!.year, t.createdAt!.month, t.createdAt!.day);
      if (d.isBefore(startDay)) continue;
      map[d] = (map[d] ?? 0) + 1;
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Consumer<CenterDataProvider>(
      builder: (context, centerData, _) {
        final colorScheme = Theme.of(context).colorScheme;
        if (centerData.loading && centerData.center == null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  'Loading center…',
                  style: textTheme.bodyLarge?.copyWith(color: colorScheme.onSurface),
                ),
              ],
            ),
          );
        }
        if (centerData.error != null && centerData.center == null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: colorScheme.error),
                const SizedBox(height: 16),
                Text(
                  centerData.error!,
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium?.copyWith(color: colorScheme.error),
                ),
              ],
            ),
          );
        }

        final c = centerData.center;
        final points = c?.points ?? 0;
        final weight = c?.totalWeight ?? 0.0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              c != null ? 'Welcome back, ${c.name}!' : 'Welcome back!',
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Your recycling center overview',
              style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _StatCard(
                  title: 'Total intakes',
                  value: _statsLoading ? '…' : '${_transactions.length}',
                  icon: Icons.insert_drive_file_outlined,
                  color: const Color(0xFF4CAF50),
                ),
                _StatCard(
                  title: 'Total weight',
                  value: '${weight.toStringAsFixed(1)} kg',
                  icon: Icons.scale_outlined,
                  color: const Color(0xFF10B981),
                ),
                _StatCard(
                  title: 'Points issued',
                  value: '$points',
                  icon: Icons.stars_rounded,
                  color: const Color(0xFFF59E0B),
                ),
                _StatCard(
                  title: 'Claimed QR codes',
                  value: _statsLoading ? '…' : '$_claimedQr',
                  icon: Icons.qr_code_2_outlined,
                  color: const Color(0xFF8B5CF6),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                  child: _statsLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _DailyIntakeChart(
                          dailyCounts: _dailyCounts(),
                          textTheme: textTheme,
                          colorScheme: colorScheme,
                        ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DailyIntakeChart extends StatelessWidget {
  const _DailyIntakeChart({
    required this.dailyCounts,
    required this.textTheme,
    required this.colorScheme,
  });

  final Map<DateTime, int> dailyCounts;
  final TextTheme textTheme;
  final ColorScheme colorScheme;

  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    final sortedKeys = dailyCounts.keys.toList()..sort();
    final values = sortedKeys.map((k) => dailyCounts[k]!.toDouble()).toList();
    final maxVal = values.isEmpty ? 1.0 : math.max(values.reduce(math.max), 1.0);
    final roundedMaxY = (maxVal * 1.3).ceilToDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.bar_chart_rounded, size: 20, color: colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              'Daily intakes (last 14 days)',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Expanded(
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: roundedMaxY,
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  tooltipBorderRadius: BorderRadius.circular(8),
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final d = sortedKeys[group.x.toInt()];
                    final label = '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}';
                    final count = rod.toY.toInt();
                    return BarTooltipItem(
                      '$label\n$count intake${count == 1 ? '' : 's'}',
                      TextStyle(
                        color: colorScheme.onPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 32,
                    interval: maxVal <= 5 ? 1 : null,
                    getTitlesWidget: (value, meta) {
                      if (value == 0 || value != value.roundToDouble()) {
                        return const SizedBox.shrink();
                      }
                      return Text(
                        '${value.toInt()}',
                        style: textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      final idx = value.toInt();
                      if (idx < 0 || idx >= sortedKeys.length) {
                        return const SizedBox.shrink();
                      }
                      final d = sortedKeys[idx];
                      final now = DateTime.now();
                      final today = DateTime(now.year, now.month, now.day);
                      String label;
                      if (d == today) {
                        label = 'Today';
                      } else {
                        label = '${d.day}/${d.month}';
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          label,
                          style: textTheme.labelSmall?.copyWith(
                            color: d == today
                                ? colorScheme.primary
                                : colorScheme.onSurfaceVariant,
                            fontSize: 10,
                            fontWeight: d == today ? FontWeight.w600 : null,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: maxVal <= 5 ? 1 : roundedMaxY / 4,
                getDrawingHorizontalLine: (_) => FlLine(
                  color: colorScheme.outlineVariant.withOpacity(0.4),
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(show: false),
              barGroups: List.generate(sortedKeys.length, (i) {
                final val = values[i];
                return BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: val,
                      width: sortedKeys.length > 10 ? 14 : 22,
                      color: val > 0
                          ? const Color(0xFF4CAF50)
                          : colorScheme.outlineVariant.withOpacity(0.15),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                    ),
                  ],
                );
              }),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfilePageView extends StatefulWidget {
  const _ProfilePageView();

  @override
  State<_ProfilePageView> createState() => _ProfilePageViewState();
}

class _ProfilePageViewState extends State<_ProfilePageView> {
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _managerNameController = TextEditingController();
  final _managerPhoneController = TextEditingController();
  final _managerEmailController = TextEditingController();
  double? _lat;
  double? _lng;
  String? _syncedCenterId;
  bool _saving = false;

  /// type -> (minKg, maxKg, pricePerKg); mirrors registration page.
  final Map<String, ({double minKg, double maxKg, double pricePerKg})> _materials = {};
  bool _materialsSynced = false;

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _managerNameController.dispose();
    _managerPhoneController.dispose();
    _managerEmailController.dispose();
    super.dispose();
  }

  void _syncFromCenter(CenterProfile c, String centerId, List<CenterMaterialEntry> mats) {
    if (_syncedCenterId == centerId) return;
    _syncedCenterId = centerId;
    _nameController.text = c.name;
    _addressController.text = c.address;
    _managerNameController.text = c.managerName;
    _managerPhoneController.text = c.managerPhone;
    _managerEmailController.text = c.managerEmail;
    _lat = c.lat;
    _lng = c.lng;

    if (!_materialsSynced) {
      _materialsSynced = true;
      _materials.clear();
      for (final m in mats) {
        _materials[m.type] = (
          minKg: m.minWeightKg,
          maxKg: m.maxWeightKg,
          pricePerKg: m.pricePerKg,
        );
      }
    }
  }

  Future<void> _save(BuildContext context) async {
    final centerData = Provider.of<CenterDataProvider>(context, listen: false);
    final centerId = centerData.centerId;
    final c = centerData.center;
    if (centerId == null || c == null) return;
    final name = _nameController.text.trim();
    final address = _addressController.text.trim();
    final managerName = _managerNameController.text.trim();
    final managerPhone = _managerPhoneController.text.trim();
    final managerEmail = _managerEmailController.text.trim();
    if (name.isEmpty || address.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name and address are required')),
      );
      return;
    }
    if (_materials.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one accepted material type.')),
      );
      return;
    }
    final lat = _lat ?? c.lat;
    final lng = _lng ?? c.lng;
    setState(() => _saving = true);
    try {
      final firestore = CenterFirestoreService();
      final materialsList = _materials.entries.map((e) {
        final label = kMaterialTypes.firstWhere((t) => t['type'] == e.key)['label'] ?? e.key;
        return CenterMaterialEntry(
          type: e.key,
          label: label,
          minWeightKg: e.value.minKg,
          maxWeightKg: e.value.maxKg,
          pricePerKg: e.value.pricePerKg,
        );
      }).toList();

      await Future.wait([
        firestore.updateCenter(
          centerId: centerId,
          name: name,
          address: address,
          lat: lat,
          lng: lng,
          managerName: managerName,
          managerPhone: managerPhone,
          managerEmail: managerEmail,
        ),
        firestore.updateMaterials(
          centerId: centerId,
          materials: materialsList,
        ),
      ]);
      _materialsSynced = false;
      _syncedCenterId = null;
      await centerData.refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile saved')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Consumer<CenterDataProvider>(
      builder: (context, centerData, _) {
        if (centerData.loading && centerData.center == null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  'Loading profile…',
                  style: textTheme.bodyLarge?.copyWith(color: colorScheme.onSurface),
                ),
              ],
            ),
          );
        }
        if (centerData.error != null && centerData.center == null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: colorScheme.error),
                const SizedBox(height: 16),
                Text(
                  centerData.error!,
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium?.copyWith(color: colorScheme.error),
                ),
              ],
            ),
          );
        }

        final c = centerData.center!;
        final centerId = centerData.centerId ?? '';
        _syncFromCenter(c, centerId, centerData.materials);

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Center profile',
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Update center information and manager contacts.',
                style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface),
              ),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _SectionTitle('Center information'),
                      const SizedBox(height: 12),
                      _LabeledTextField(
                        controller: _nameController,
                        label: 'Center name',
                        hint: 'Green Earth Recycling',
                      ),
                      const SizedBox(height: 12),
                      AddressMapPicker(
                        initialAddress: _addressController.text.isEmpty ? null : _addressController.text,
                        initialLat: _lat,
                        initialLng: _lng,
                        onLocationSelected: (lat, lng, address) {
                          debugPrint(
                            '[ProfilePage] onLocationSelected lat=$lat, lng=$lng, address="$address"',
                          );
                          setState(() {
                            _lat = lat;
                            _lng = lng;
                            _addressController.text = address;
                          });
                          debugPrint(
                            '[ProfilePage] state updated _lat=$_lat, _lng=$_lng, '
                            'address="${_addressController.text}"',
                          );
                        },
                        height: 220,
                      ),
                      const SizedBox(height: 24),
                      const _SectionTitle('Manager'),
                      const SizedBox(height: 12),
                      _LabeledTextField(
                        controller: _managerNameController,
                        label: 'Manager name',
                        hint: 'John Smith',
                      ),
                      const SizedBox(height: 12),
                      _LabeledTextField(
                        controller: _managerPhoneController,
                        label: 'Manager phone',
                        hint: '+60 12-345 6789',
                      ),
                      const SizedBox(height: 12),
                      _LabeledTextField(
                        controller: _managerEmailController,
                        label: 'Manager email',
                        hint: 'manager@center.com',
                      ),
                      const SizedBox(height: 24),
                      const _SectionTitle('Accepted materials'),
                      const SizedBox(height: 4),
                      Text(
                        'Select types and set min/max weight (kg) and price per kg (0 = free).',
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...kMaterialTypes.map((mat) {
                        final type = mat['type']!;
                        final label = mat['label']!;
                        final isSelected = _materials.containsKey(type);
                        final params = _materials[type] ??
                            (minKg: 0.5, maxKg: 100.0, pricePerKg: 0.0);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _MaterialRow(
                            icon: getMaterialIcon(type),
                            label: label,
                            selected: isSelected,
                            minKg: isSelected ? params.minKg : 0.5,
                            maxKg: isSelected ? params.maxKg : 100.0,
                            pricePerKg: isSelected ? params.pricePerKg : 0.0,
                            onChanged: (selected) {
                              setState(() {
                                if (selected) {
                                  _materials[type] = (
                                    minKg: 0.5,
                                    maxKg: 100.0,
                                    pricePerKg: 0.0,
                                  );
                                } else {
                                  _materials.remove(type);
                                }
                              });
                            },
                            onMinChanged: (v) {
                              setState(() {
                                final p = _materials[type]!;
                                _materials[type] = (
                                  minKg: v,
                                  maxKg: p.maxKg,
                                  pricePerKg: p.pricePerKg,
                                );
                              });
                            },
                            onMaxChanged: (v) {
                              setState(() {
                                final p = _materials[type]!;
                                _materials[type] = (
                                  minKg: p.minKg,
                                  maxKg: v,
                                  pricePerKg: p.pricePerKg,
                                );
                              });
                            },
                            onPriceChanged: (v) {
                              setState(() {
                                final p = _materials[type]!;
                                _materials[type] = (
                                  minKg: p.minKg,
                                  maxKg: p.maxKg,
                                  pricePerKg: v,
                                );
                              });
                            },
                          ),
                        );
                      }),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _saving ? null : () => _save(context),
                          icon: _saving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.check_rounded),
                          label: Text(_saving ? 'Saving…' : 'Save changes'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
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
      },
    );
  }
}

class _NewIntakePageView extends StatefulWidget {
  const _NewIntakePageView();

  @override
  State<_NewIntakePageView> createState() => _NewIntakePageViewState();
}

/// Payload prefix for QR so mobile app can recognize and claim.
const String kQrPayloadPrefix = 'KITAKITAR_QR:';

class _NewIntakePageViewState extends State<_NewIntakePageView> {
  /// Selected material types -> weight (kg). Empty = none selected.
  final Map<String, TextEditingController> _weightControllers = {};
  /// After "Generate QR code", the created document id. Null until generated.
  String? _generatedQrId;
  bool _isGenerating = false;

  @override
  void dispose() {
    for (final c in _weightControllers.values) {
      c.dispose();
    }
    _weightControllers.clear();
    super.dispose();
  }

  void _toggleMaterial(CenterMaterialEntry m) {
    if (_weightControllers.containsKey(m.type)) {
      _weightControllers[m.type]?.dispose();
      _weightControllers.remove(m.type);
    } else {
      _weightControllers[m.type] = TextEditingController(text: '');
    }
    setState(() {});
  }

  Future<void> _generateQr(
      BuildContext context, CenterDataProvider centerData) async {
    final centerId = centerData.centerId;
    final materials = centerData.materials;
    if (centerId == null || materials.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Center not loaded or no materials configured.')),
      );
      return;
    }
    final list = <({String type, double weightKg})>[];
    for (final e in _weightControllers.entries) {
      final w = double.tryParse(e.value.text.replaceAll(',', '.')) ?? 0;
      if (w <= 0) continue;
      list.add((type: e.key, weightKg: w));
    }
    if (list.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Select at least one material and enter weight (kg) > 0 for each.'),
        ),
      );
      return;
    }
    setState(() => _isGenerating = true);
    try {
      final qrId = await CenterFirestoreService().createIntakeQr(
        centerId: centerId,
        materialsWithWeights: list,
        centerMaterials: materials,
      );
      if (!mounted) return;
      setState(() {
        _generatedQrId = qrId;
        _isGenerating = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('QR code created. Client can scan to claim.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isGenerating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Consumer<CenterDataProvider>(
      builder: (context, centerData, _) {
        final materials = centerData.materials;
        final selectedEntries = materials
            .where((m) => _weightControllers.containsKey(m.type))
            .toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'New intake',
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Select one or more materials received and enter weight for each (e.g. mixed load).',
              style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const _SectionTitle('Select materials'),
                            const SizedBox(height: 8),
                            Text(
                              'Tap to add or remove. Then enter weight (kg) for each below.',
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (materials.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                child: Text(
                                  'No materials configured. Add accepted materials in Center profile first.',
                                  style: textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                              )
                            else
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: materials.map((m) {
                                  final selected =
                                      _weightControllers.containsKey(m.type);
                                  return _MaterialPill(
                                    icon: _materialEmoji(m.type),
                                    label: m.label,
                                    selected: selected,
                                    onTap: () => _toggleMaterial(m),
                                  );
                                }).toList(),
                              ),
                            const SizedBox(height: 24),
                            const _SectionTitle('Weight per material (kg)'),
                            const SizedBox(height: 12),
                            if (selectedEntries.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Text(
                                  'Select at least one material above.',
                                  style: textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                              )
                            else
                              ...selectedEntries.map((m) {
                                final controller = _weightControllers[m.type]!;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.end,
                                    children: [
                                      Icon(
                                        getMaterialIcon(m.type),
                                        size: 22,
                                        color: colorScheme.primary,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          m.label,
                                          style: textTheme.bodyMedium?.copyWith(
                                            color: colorScheme.onSurface,
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: 100,
                                        child: TextField(
                                          controller: controller,
                                          keyboardType: const TextInputType
                                              .numberWithOptions(decimal: true),
                                          decoration: InputDecoration(
                                            labelText: 'kg',
                                            hintText:
                                                '${m.minWeightKg}–${m.maxWeightKg}',
                                            isDense: true,
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 10),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: _isGenerating
                                    ? null
                                    : () => _generateQr(context, centerData),
                                icon: _isGenerating
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.qr_code_2_rounded),
                                label: Text(
                                  _isGenerating
                                      ? 'Generating…'
                                      : 'Generate QR code',
                                ),
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    flex: 2,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const _SectionTitle('QR code'),
                            const SizedBox(height: 12),
                            if (_generatedQrId == null)
                              Container(
                                height: 220,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(24),
                                  color: colorScheme.surfaceContainerHighest,
                                ),
                                child: Center(
                                  child: Text(
                                    'Select materials, enter weights,\nthen tap Generate QR code.',
                                    textAlign: TextAlign.center,
                                    style: textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                              )
                            else
                              Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: QrImageView(
                                      data: '$kQrPayloadPrefix$_generatedQrId',
                                      version: QrVersions.auto,
                                      size: 200,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Client scans this QR in the mobile app to receive points.',
                                    style: textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextButton.icon(
                                    onPressed: () => setState(() {
                                      _generatedQrId = null;
                                    }),
                                    icon: const Icon(Icons.add_circle_outline,
                                        size: 18),
                                    label: const Text('Create another'),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  static String _materialEmoji(String type) {
    const map = {
      'paper': '📄',
      'plastic': '🥤',
      'glass': '🍾',
      'aluminum': '🥫',
      'batteries': '🔋',
      'electronics': '📱',
      'food': '🍎',
      'lawn': '🌿',
      'used_oil': '🛢️',
      'hazardous_waste': '⚠️',
      'tires': '🛞',
      'metal': '🔩',
    };
    return map[type] ?? '♻️';
  }
}

class _QrCodesPageView extends StatefulWidget {
  const _QrCodesPageView({required this.centerId});

  final String centerId;

  @override
  State<_QrCodesPageView> createState() => _QrCodesPageViewState();
}

class _QrCodesPageViewState extends State<_QrCodesPageView> {
  List<QrCodeListItem> _pending = [];
  List<QrCodeListItem> _completed = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final firestore = CenterFirestoreService();
    final pending = await firestore.getPendingQrCodes(widget.centerId);
    final completed = await firestore.getCompletedQrCodes(widget.centerId);
    if (!mounted) return;
    setState(() {
      _pending = pending;
      _completed = completed;
      _loading = false;
    });
  }

  void _showQrScanDialog(BuildContext context, QrCodeListItem item) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Scan to claim',
                  style: textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: QrImageView(
                      data: '$kQrPayloadPrefix${item.id}',
                      version: QrVersions.auto,
                      size: 220,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '${item.totalWeight.toStringAsFixed(1)} kg · ${item.materialsCount} material(s)',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Client scans this QR in the mobile app to receive points.',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'QR codes',
          style: textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Track pending and claimed QR codes.',
          style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface),
        ),
        const SizedBox(height: 24),
        Expanded(
          child: _loading
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(
                        'Loading…',
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                )
              : Row(
                  children: [
                    Expanded(
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const _SectionTitle('Pending QR codes'),
                                  const Spacer(),
                                  TextButton.icon(
                                    onPressed: _loading ? null : _load,
                                    icon: const Icon(Icons.refresh, size: 18),
                                    label: const Text('Refresh'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Expanded(
                                child: _pending.isEmpty
                                    ? Center(
                                        child: Text(
                                          'No pending QR codes.\nGenerate one in New intake.',
                                          textAlign: TextAlign.center,
                                          style: textTheme.bodyMedium?.copyWith(
                                            color: colorScheme.onSurface,
                                          ),
                                        ),
                                      )
                                    : ListView.builder(
                                        itemCount: _pending.length,
                                        itemBuilder: (context, i) {
                                          final e = _pending[i];
                                          return _QrCodeListTile(
                                            item: e,
                                            colorScheme: colorScheme,
                                            textTheme: textTheme,
                                            onTap: () => _showQrScanDialog(context, e),
                                          );
                                        },
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const _SectionTitle('Claimed QR codes'),
                                  const Spacer(),
                                  TextButton.icon(
                                    onPressed: _loading ? null : _load,
                                    icon: const Icon(Icons.refresh, size: 18),
                                    label: const Text('Refresh'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Expanded(
                                child: _completed.isEmpty
                                    ? Center(
                                        child: Text(
                                          'No claimed QR codes yet.',
                                          textAlign: TextAlign.center,
                                          style: textTheme.bodyMedium?.copyWith(
                                            color: colorScheme.onSurface,
                                          ),
                                        ),
                                      )
                                    : ListView.builder(
                                        itemCount: _completed.length,
                                        itemBuilder: (context, i) {
                                          final e = _completed[i];
                                          return _QrCodeListTile(
                                            item: e,
                                            colorScheme: colorScheme,
                                            textTheme: textTheme,
                                            isClaimed: true,
                                          );
                                        },
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _QrCodeListTile extends StatelessWidget {
  const _QrCodeListTile({
    required this.item,
    required this.colorScheme,
    required this.textTheme,
    this.isClaimed = false,
    this.onTap,
  });

  final QrCodeListItem item;
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final bool isClaimed;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final date = item.createdAt != null
        ? _formatDate(item.createdAt!)
        : '—';
    final usedInfo = isClaimed && item.usedAt != null
        ? 'Claimed ${_formatDate(item.usedAt!)}'
        : null;
    Widget content = Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isClaimed ? Icons.check_circle : Icons.qr_code_2_outlined,
                  size: 20,
                  color: isClaimed
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${item.totalWeight.toStringAsFixed(1)} kg · ${item.materialsCount} material(s)',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Created $date',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            if (usedInfo != null) ...[
              const SizedBox(height: 2),
              Text(
                usedInfo,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.primary,
                ),
              ),
            ],
            const SizedBox(height: 2),
            Text(
              'ID: ${item.id}',
              style: textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontFamily: 'monospace',
              ),
            ),
            if (onTap != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Tap to show QR for scanning',
                  style: textTheme.labelSmall?.copyWith(
                    color: colorScheme.primary,
                  ),
                ),
              ),
          ],
        ),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: onTap != null
          ? InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              child: content,
            )
          : content,
    );
  }

  static String _formatDate(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}

class _HistoryPageView extends StatefulWidget {
  const _HistoryPageView({required this.centerId});

  final String centerId;

  @override
  State<_HistoryPageView> createState() => _HistoryPageViewState();
}

class _HistoryPageViewState extends State<_HistoryPageView> {
  List<TransactionListItem> _transactions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await CenterFirestoreService().getTransactions(widget.centerId);
    if (!mounted) return;
    setState(() {
      _transactions = list;
      _loading = false;
    });
  }

  static String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}  '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  static String _materialsSummary(List<TransactionMaterial> mats) {
    if (mats.isEmpty) return '—';
    return mats.map((m) {
      final label = kMaterialTypes
              .cast<Map<String, String>?>()
              .firstWhere((t) => t?['type'] == m.type, orElse: () => null)
              ?['label'] ??
          m.type;
      return '$label (${m.weight.toStringAsFixed(1)} kg)';
    }).join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Intake history',
          style: textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'All completed transactions for this center.',
          style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface),
        ),
        const SizedBox(height: 24),
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const _SectionTitle('Transactions'),
                      const SizedBox(width: 8),
                      if (!_loading)
                        Text(
                          '(${_transactions.length})',
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: _loading ? null : _load,
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Refresh'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: _loading
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const CircularProgressIndicator(),
                                const SizedBox(height: 16),
                                Text(
                                  'Loading transactions…',
                                  style: textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : _transactions.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.receipt_long_outlined,
                                        size: 48,
                                        color: colorScheme.onSurfaceVariant),
                                    const SizedBox(height: 12),
                                    Text(
                                      'No transactions yet.\nTransactions appear after a user scans a QR code.',
                                      textAlign: TextAlign.center,
                                      style: textTheme.bodyMedium?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : _TransactionTable(
                                transactions: _transactions,
                                textTheme: textTheme,
                                colorScheme: colorScheme,
                              ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TransactionTable extends StatelessWidget {
  const _TransactionTable({
    required this.transactions,
    required this.textTheme,
    required this.colorScheme,
  });

  final List<TransactionListItem> transactions;
  final TextTheme textTheme;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: SizedBox(
            width: constraints.maxWidth,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(
                colorScheme.surfaceContainerHighest.withOpacity(0.5),
              ),
              columnSpacing: 24,
              horizontalMargin: 16,
              columns: const [
                DataColumn(label: Text('Date')),
                DataColumn(label: Text('Materials')),
                DataColumn(label: Text('Weight'), numeric: true),
                DataColumn(label: Text('Points'), numeric: true),
                DataColumn(label: Text('QR Code')),
              ],
              rows: transactions.map((t) {
                final date = t.createdAt != null
                    ? _HistoryPageViewState._fmtDate(t.createdAt!)
                    : '—';
                return DataRow(cells: [
                  DataCell(Text(
                    date,
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface,
                    ),
                  )),
                  DataCell(
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 320),
                      child: Text(
                        _HistoryPageViewState._materialsSummary(t.materials),
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ),
                  ),
                  DataCell(Text(
                    '${t.totalWeight.toStringAsFixed(1)} kg',
                    style: textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  )),
                  DataCell(Text(
                    '${t.pointsCenter}',
                    style: textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.primary,
                    ),
                  )),
                  DataCell(
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 180),
                      child: Text(
                        t.qrCodeId ?? '—',
                        style: textTheme.labelSmall?.copyWith(
                          fontFamily: 'monospace',
                          color: colorScheme.onSurfaceVariant,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ]);
              }).toList(),
            ),
          ),
        );
      },
    );
  }
}

/// -----------------------
/// SMALL REUSABLE WIDGETS
/// -----------------------

class _MaterialRow extends StatefulWidget {
  const _MaterialRow({
    required this.icon,
    required this.label,
    required this.selected,
    required this.minKg,
    required this.maxKg,
    required this.pricePerKg,
    required this.onChanged,
    required this.onMinChanged,
    required this.onMaxChanged,
    required this.onPriceChanged,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final double minKg;
  final double maxKg;
  final double pricePerKg;
  final ValueChanged<bool> onChanged;
  final ValueChanged<double> onMinChanged;
  final ValueChanged<double> onMaxChanged;
  final ValueChanged<double> onPriceChanged;

  @override
  State<_MaterialRow> createState() => _MaterialRowState();
}

class _MaterialRowState extends State<_MaterialRow> {
  late TextEditingController _minController;
  late TextEditingController _maxController;
  late TextEditingController _priceController;

  @override
  void initState() {
    super.initState();
    _minController = TextEditingController(text: _formatNum(widget.minKg));
    _maxController = TextEditingController(text: _formatNum(widget.maxKg));
    _priceController = TextEditingController(text: _formatNum(widget.pricePerKg));
  }

  @override
  void didUpdateWidget(_MaterialRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.minKg != widget.minKg) _minController.text = _formatNum(widget.minKg);
    if (oldWidget.maxKg != widget.maxKg) _maxController.text = _formatNum(widget.maxKg);
    if (oldWidget.pricePerKg != widget.pricePerKg) _priceController.text = _formatNum(widget.pricePerKg);
  }

  static String _formatNum(double v) => v == v.roundToDouble() ? '${v.toInt()}' : v.toString();

  @override
  void dispose() {
    _minController.dispose();
    _maxController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFF4CAF50).withOpacity(0.08) : null,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected ? const Color(0xFF4CAF50).withOpacity(0.3) : Colors.grey.shade300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Checkbox(
                value: selected,
                onChanged: (v) => widget.onChanged(v ?? false),
                activeColor: const Color(0xFF4CAF50),
              ),
              Icon(
                widget.icon,
                size: 22,
                color: selected ? const Color(0xFF4CAF50) : Colors.grey.shade600,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                      ),
                ),
              ),
            ],
          ),
          if (selected) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                SizedBox(
                  width: 72,
                  child: TextField(
                    controller: _minController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Min kg',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    ),
                    onChanged: (v) => widget.onMinChanged(double.tryParse(v.replaceAll(',', '.')) ?? 0),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 72,
                  child: TextField(
                    controller: _maxController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Max kg',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    ),
                    onChanged: (v) => widget.onMaxChanged(double.tryParse(v.replaceAll(',', '.')) ?? 0),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 88,
                  child: TextField(
                    controller: _priceController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Price/kg',
                      hintText: '0=free',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    ),
                    onChanged: (v) => widget.onPriceChanged(double.tryParse(v.replaceAll(',', '.')) ?? 0),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _LogoHeader extends StatelessWidget {
  const _LogoHeader({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 64,
          height: 64,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
              ),
            ),
          child: const Icon(
            Icons.recycling_rounded,
            color: Colors.white,
            size: 34,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          title,
          textAlign: TextAlign.center,
          style:
              textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
        ),
      ],
    );
  }
}

class _EmailField extends StatelessWidget {
  const _EmailField({this.controller});

  final TextEditingController? controller;

  @override
  Widget build(BuildContext context) {
    return _LabeledTextField(
      controller: controller,
      label: 'Email',
      hint: 'center@example.com',
    );
  }
}

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    this.controller,
    required this.obscure,
    required this.onToggleObscure,
  });

  final TextEditingController? controller;
  final bool obscure;
  final VoidCallback onToggleObscure;

  @override
  Widget build(BuildContext context) {
    return _LabeledTextField(
      controller: controller,
      label: 'Password',
      hint: '••••••••',
      obscure: obscure,
    );
  }
}

class _LabeledTextField extends StatelessWidget {
  const _LabeledTextField({
    required this.label,
    required this.hint,
    this.icon,
    this.obscure = false,
    this.keyboardType,
    this.controller,
  });

  final String label;
  final String hint;
  final IconData? icon;
  final bool obscure;
  final TextInputType? keyboardType;
  final TextEditingController? controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context)
              .textTheme
              .labelMedium
              ?.copyWith(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: icon != null ? Icon(icon) : null,
          ),
        ),
      ],
    );
  }
}

class _BulletPoint extends StatelessWidget {
  const _BulletPoint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle, size: 18, color: Color(0xFF10B981)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.grey.shade700),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: 220,
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: Colors.white, size: 22),
                ),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              value,
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: textTheme.bodySmall?.copyWith(
                color: Colors.white.withOpacity(0.85),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context)
          .textTheme
          .titleMedium
          ?.copyWith(fontWeight: FontWeight.bold),
    );
  }
}

class _ChipTag extends StatelessWidget {
  const _ChipTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label),
      backgroundColor: const Color(0xFFE8F5E9),
      labelStyle: Theme.of(context)
          .textTheme
          .bodySmall
          ?.copyWith(color: const Color(0xFF4CAF50)),
    );
  }
}

class _PrimarySaveButton extends StatelessWidget {
  const _PrimarySaveButton({this.label = 'Save changes'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: FilledButton.icon(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$label (UI only, wire to backend later)'),
            ),
          );
        },
        icon: const Icon(Icons.check_rounded),
        label: Text(label),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

class _MaterialPill extends StatelessWidget {
  const _MaterialPill({
    required this.icon,
    required this.label,
    this.selected = false,
    this.onTap,
  });

  final String icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = selected ? colorScheme.primary : colorScheme.onSurfaceVariant;

    final child = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: selected
            ? colorScheme.primary.withOpacity(0.12)
            : colorScheme.surfaceContainerHighest,
        border: Border.all(
          color: selected
              ? colorScheme.primary.withOpacity(0.5)
              : colorScheme.outlineVariant,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: child,
      );
    }
    return child;
  }
}
