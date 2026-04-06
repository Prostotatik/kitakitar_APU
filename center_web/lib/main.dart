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
import 'theme/cyberpunk_theme.dart';

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
        theme: buildCyberpunkTheme(),
        home: const _RootShell(),
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
    final auth = Provider.of<CenterAuthProvider>(context);

    return Scaffold(
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
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Container(
                  margin: const EdgeInsets.all(24),
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: CyberpunkColors.darkMatter,
                    border: Border.all(color: CyberpunkColors.neonGreen, width: 2),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: NeonGlow.greenGlow(blur: 20),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const CyberpunkLogoHeader(
                        title: 'KITAKITAR CENTER',
                        subtitle: 'ADMIN PANEL FOR RECYCLING CENTERS',
                        iconSize: 48,
                      ),
                      const SizedBox(height: 32),
                      Text(
                        'LOG IN TO YOUR CENTER',
                        style: TextStyle(
                          color: CyberpunkColors.mistGray,
                          fontSize: 10,
                          fontFamily: 'PressStart2P',
                        ),
                      ),
                      const SizedBox(height: 24),
                      NeonTextField(
                        controller: _emailController,
                        labelText: 'EMAIL',
                        hintText: 'center@example.com',
                        prefixIcon: Icons.email,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 16),
                      NeonTextField(
                        controller: _passwordController,
                        labelText: 'PASSWORD',
                        hintText: '••••••••',
                        prefixIcon: Icons.lock,
                        obscureText: _obscurePassword,
                        suffixIcon: _obscurePassword ? Icons.visibility : Icons.visibility_off,
                        onToggleObscure: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                      const SizedBox(height: 24),
                      PixelButton(
                        text: auth.isLoading ? 'LOADING...' : 'ACCESS SYSTEM',
                        neonColor: CyberpunkColors.neonGreen,
                        isLoading: auth.isLoading,
                        onPressed: auth.isLoading ? null : _handleLogin,
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: PixelButton(
                          text: 'RECOVER PASSWORD',
                          neonColor: CyberpunkColors.hotPink,
                          isOutlined: true,
                          fontSize: 10,
                          onPressed: widget.onGoToForgot,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 1,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.transparent,
                                    CyberpunkColors.neonGreen.withOpacity(0.5),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'OR',
                              style: TextStyle(
                                color: CyberpunkColors.dimGray,
                                fontSize: 10,
                                fontFamily: 'PressStart2P',
                              ),
                            ),
                          ),
                          Expanded(
                            child: Container(
                              height: 1,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.transparent,
                                    CyberpunkColors.neonGreen.withOpacity(0.5),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'NO CENTER YET?',
                            style: TextStyle(
                              color: CyberpunkColors.mistGray,
                              fontSize: 9,
                              fontFamily: 'PressStart2P',
                            ),
                          ),
                          const SizedBox(width: 12),
                          PixelButton(
                            text: 'CREATE',
                            neonColor: CyberpunkColors.neonCyan,
                            fontSize: 10,
                            isOutlined: true,
                            onPressed: widget.onGoToRegister,
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
    debugPrint('[RegisterCenterPage] onLocationSelected lat=$lat, lng=$lng, address="$address"');
    setState(() {
      _lat = lat;
      _lng = lng;
      _addressController.text = address;
    });
    debugPrint('[RegisterCenterPage] state updated _lat=$_lat, _lng=$_lng, address="${_addressController.text}"');
  }

  Future<void> _submit() async {
    final address = _addressController.text.trim();
    if (address.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a point on the map and/or enter an address.')),
      );
      return;
    }
    if (_lat == null || _lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter an address (suggestions as you type) or tap on the map.')),
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
        const SnackBar(content: Text('Fill in center name and manager details.')),
      );
      return;
    }
    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter email and password for the center account.')),
      );
      return;
    }
    if (_materials.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one accepted material type.')),
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
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(color: CyberpunkColors.voidBlack),
        child: Stack(
          children: [
            CustomPaint(
              painter: CircuitGridPainter(color: CyberpunkColors.neonCyan, gridSize: 50),
              size: Size.infinite,
            ),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Container(
                  margin: const EdgeInsets.all(24),
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: CyberpunkColors.darkMatter,
                    border: Border.all(color: CyberpunkColors.neonCyan, width: 2),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: NeonGlow.cyanGlow(blur: 20),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CyberpunkLogoHeader(
                          title: 'NEW CENTER REGISTRATION',
                          subtitle: 'JOIN THE KITAKITAR NETWORK',
                          iconSize: 40,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'WHY JOIN?',
                          style: TextStyle(
                            color: CyberpunkColors.amber,
                            fontSize: 10,
                            fontFamily: 'PressStart2P',
                            shadows: NeonGlow.amberTextGlow(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildBulletPoint('Configure accepted materials, weight ranges and pricing.'),
                        _buildBulletPoint('Generate one-time QR codes for every accepted load.'),
                        _buildBulletPoint('Track statistics and points for your center in real time.'),
                        const SizedBox(height: 24),
                        const Divider(color: CyberpunkColors.neonCyan, height: 1),
                        const SizedBox(height: 24),
                        // Center details section
                        Text(
                          'CENTER DETAILS',
                          style: TextStyle(
                            color: CyberpunkColors.neonGreen,
                            fontSize: 10,
                            fontFamily: 'PressStart2P',
                            shadows: NeonGlow.greenTextGlow(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        NeonTextField(
                          controller: _centerNameController,
                          labelText: 'CENTER NAME',
                          hintText: 'Green Earth Recycling',
                        ),
                        const SizedBox(height: 16),
                        // Address map picker would go here (keeping original functionality)
                        AddressMapPicker(
                          initialAddress: _addressController.text.isEmpty ? null : _addressController.text,
                          initialLat: _lat,
                          initialLng: _lng,
                          onLocationSelected: _onLocationSelected,
                          height: 200,
                        ),
                        const SizedBox(height: 24),
                        // Manager section
                        Text(
                          'MANAGER',
                          style: TextStyle(
                            color: CyberpunkColors.neonGreen,
                            fontSize: 10,
                            fontFamily: 'PressStart2P',
                            shadows: NeonGlow.greenTextGlow(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: NeonTextField(
                                controller: _managerNameController,
                                labelText: 'NAME',
                                hintText: 'John Smith',
                                isSmall: true,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: NeonTextField(
                                controller: _managerPhoneController,
                                labelText: 'PHONE',
                                hintText: '+60 12-345 6789',
                                isSmall: true,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        // Materials section
                        Text(
                          'ACCEPTED MATERIALS',
                          style: TextStyle(
                            color: CyberpunkColors.neonGreen,
                            fontSize: 10,
                            fontFamily: 'PressStart2P',
                            shadows: NeonGlow.greenTextGlow(),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Select types and set min/max weight (kg) and price per kg (0 = free).',
                          style: TextStyle(
                            color: CyberpunkColors.mistGray,
                            fontSize: 10,
                            fontFamily: 'RobotoMono',
                          ),
                        ),
                        const SizedBox(height: 12),
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
                        const SizedBox(height: 24),
                        // Account section
                        Text(
                          'ACCOUNT',
                          style: TextStyle(
                            color: CyberpunkColors.neonGreen,
                            fontSize: 10,
                            fontFamily: 'PressStart2P',
                            shadows: NeonGlow.greenTextGlow(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        NeonTextField(
                          controller: _emailController,
                          labelText: 'EMAIL',
                          hintText: 'center@example.com',
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 12),
                        NeonTextField(
                          controller: _passwordController,
                          labelText: 'PASSWORD',
                          hintText: '••••••••',
                          obscureText: true,
                        ),
                        const SizedBox(height: 12),
                        NeonTextField(
                          controller: _confirmPasswordController,
                          labelText: 'CONFIRM PASSWORD',
                          hintText: '••••••••',
                          obscureText: true,
                        ),
                        const SizedBox(height: 24),
                        PixelButton(
                          text: _isSubmitting ? 'CREATING...' : 'CREATE CENTER ACCOUNT',
                          neonColor: CyberpunkColors.neonCyan,
                          isLoading: _isSubmitting,
                          onPressed: _isSubmitting ? null : _submit,
                        ),
                        const SizedBox(height: 16),
                        Center(
                          child: PixelButton(
                            text: 'ALREADY HAVE ACCOUNT? LOGIN',
                            neonColor: CyberpunkColors.neonGreen,
                            fontSize: 10,
                            isOutlined: true,
                            onPressed: widget.onGoToLogin,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: CyberpunkColors.neonGreen, size: 16),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: CyberpunkColors.mistGray,
                fontSize: 11,
                fontFamily: 'RobotoMono',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MaterialRow extends StatelessWidget {
  const _MaterialRow({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onChanged,
    required this.minKg,
    required this.maxKg,
    required this.pricePerKg,
    required this.onMinChanged,
    required this.onMaxChanged,
    required this.onPriceChanged,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final ValueChanged<bool> onChanged;
  final double minKg;
  final double maxKg;
  final double pricePerKg;
  final ValueChanged<double> onMinChanged;
  final ValueChanged<double> onMaxChanged;
  final ValueChanged<double> onPriceChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CyberpunkColors.circuitBoard,
        border: Border.all(
          color: selected ? CyberpunkColors.neonGreen : CyberpunkColors.terminalGray,
          width: selected ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Checkbox(
            value: selected,
            onChanged: (v) => onChanged(v ?? false),
            activeColor: CyberpunkColors.neonGreen,
            checkColor: CyberpunkColors.voidBlack,
          ),
          Icon(icon, size: 20, color: selected ? CyberpunkColors.neonGreen : CyberpunkColors.mistGray),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label.toUpperCase(),
              style: TextStyle(
                color: selected ? CyberpunkColors.neonGreen : CyberpunkColors.mistGray,
                fontSize: 10,
                fontFamily: 'PressStart2P',
              ),
            ),
          ),
          if (selected) ...[
            SizedBox(
              width: 60,
              child: TextFormField(
                initialValue: minKg.toString(),
                keyboardType: TextInputType.number,
                style: TextStyle(color: CyberpunkColors.pureWhite, fontSize: 11),
                decoration: InputDecoration(
                  hintText: 'Min',
                  hintStyle: TextStyle(color: CyberpunkColors.dimGray, fontSize: 10),
                  filled: true,
                  fillColor: CyberpunkColors.darkMatter,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: BorderSide(color: CyberpunkColors.neonGreen, width: 1),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                ),
                onChanged: (v) => onMinChanged(double.tryParse(v) ?? 0.5),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 60,
              child: TextFormField(
                initialValue: maxKg.toString(),
                keyboardType: TextInputType.number,
                style: TextStyle(color: CyberpunkColors.pureWhite, fontSize: 11),
                decoration: InputDecoration(
                  hintText: 'Max',
                  hintStyle: TextStyle(color: CyberpunkColors.dimGray, fontSize: 10),
                  filled: true,
                  fillColor: CyberpunkColors.darkMatter,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: BorderSide(color: CyberpunkColors.neonGreen, width: 1),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                ),
                onChanged: (v) => onMaxChanged(double.tryParse(v) ?? 100.0),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 60,
              child: TextFormField(
                initialValue: pricePerKg.toString(),
                keyboardType: TextInputType.number,
                style: TextStyle(color: CyberpunkColors.pureWhite, fontSize: 11),
                decoration: InputDecoration(
                  hintText: 'Price',
                  hintStyle: TextStyle(color: CyberpunkColors.dimGray, fontSize: 10),
                  filled: true,
                  fillColor: CyberpunkColors.darkMatter,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: BorderSide(color: CyberpunkColors.neonGreen, width: 1),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                ),
                onChanged: (v) => onPriceChanged(double.tryParse(v) ?? 0.0),
              ),
            ),
          ],
        ],
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
        decoration: const BoxDecoration(color: CyberpunkColors.voidBlack),
        child: Stack(
          children: [
            CustomPaint(
              painter: CircuitGridPainter(color: CyberpunkColors.hotPink, gridSize: 50),
              size: Size.infinite,
            ),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Container(
                  margin: const EdgeInsets.all(24),
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: CyberpunkColors.darkMatter,
                    border: Border.all(color: CyberpunkColors.hotPink, width: 2),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: NeonGlow.pinkGlow(blur: 20),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const CyberpunkLogoHeader(
                        title: 'PASSWORD RECOVERY',
                        subtitle: 'RESTORE YOUR ACCESS',
                        iconSize: 40,
                      ),
                      const SizedBox(height: 32),
                      Text(
                        'ENTER YOUR EMAIL FOR RECOVERY INSTRUCTIONS',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: CyberpunkColors.mistGray,
                          fontSize: 9,
                          fontFamily: 'PressStart2P',
                        ),
                      ),
                      const SizedBox(height: 24),
                      NeonTextField(
                        labelText: 'EMAIL',
                        hintText: 'center@example.com',
                        prefixIcon: Icons.email,
                        neonColor: CyberpunkColors.hotPink,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 24),
                      PixelButton(
                        text: 'SEND RECOVERY',
                        neonColor: CyberpunkColors.hotPink,
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('If an account exists, reset link will be sent.')),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: PixelButton(
                          text: 'BACK TO LOGIN',
                          neonColor: CyberpunkColors.neonGreen,
                          fontSize: 10,
                          isOutlined: true,
                          onPressed: onBackToLogin,
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
          CyberpunkSidebar(
            currentIndex: _page.index,
            onTap: (p) => setState(() => _page = _DashboardPage.values[p]),
            items: [
              const SidebarNavItem(icon: Icons.space_dashboard_outlined, label: 'Dashboard'),
              const SidebarNavItem(icon: Icons.storefront_outlined, label: 'Center Profile'),
              const SidebarNavItem(icon: Icons.add_circle_outline, label: 'New Intake'),
              const SidebarNavItem(icon: Icons.qr_code_2_outlined, label: 'QR Codes'),
              const SidebarNavItem(icon: Icons.history_rounded, label: 'History'),
            ],
            onLogout: widget.onLogout,
            title: 'KITAKITAR',
            subtitle: 'CENTER ADMIN',
          ),
          Expanded(
            child: Container(
              color: CyberpunkColors.voidBlack,
              child: Stack(
                children: [
                  CustomPaint(
                    painter: CircuitGridPainter(color: CyberpunkColors.neonGreen.withOpacity(0.3), gridSize: 60),
                    size: Size.infinite,
                  ),
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: _buildPage(),
                  ),
                ],
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

/// -----------------------
/// DASHBOARD PAGES
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
    return Consumer<CenterDataProvider>(
      builder: (context, centerData, _) {
        if (centerData.loading && centerData.center == null) {
          return Center(
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
                  'LOADING CENTER...',
                  style: TextStyle(
                    color: CyberpunkColors.neonGreen,
                    fontSize: 10,
                    fontFamily: 'PressStart2P',
                  ),
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
                Icon(Icons.error_outline, size: 48, color: CyberpunkColors.hotPink),
                const SizedBox(height: 16),
                Text(
                  centerData.error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: CyberpunkColors.hotPink,
                    fontSize: 12,
                    fontFamily: 'PressStart2P',
                  ),
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
              c != null ? 'WELCOME BACK, ${c.name.toUpperCase()}!' : 'WELCOME BACK!',
              style: TextStyle(
                color: CyberpunkColors.neonGreen,
                fontSize: 14,
                fontFamily: 'PressStart2P',
                fontWeight: FontWeight.w700,
                shadows: NeonGlow.greenTextGlow(),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Your recycling center overview',
              style: TextStyle(
                color: CyberpunkColors.mistGray,
                fontSize: 11,
                fontFamily: 'RobotoMono',
              ),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                StatCard(
                  label: 'Total Intakes',
                  value: _statsLoading ? '...' : '${_transactions.length}',
                  icon: Icons.insert_drive_file_outlined,
                  color: CyberpunkColors.neonGreen,
                ),
                StatCard(
                  label: 'Total Weight',
                  value: '${weight.toStringAsFixed(1)} KG',
                  icon: Icons.scale_outlined,
                  color: CyberpunkColors.neonCyan,
                ),
                StatCard(
                  label: 'Points Issued',
                  value: '$points',
                  icon: Icons.stars_rounded,
                  color: CyberpunkColors.amber,
                ),
                StatCard(
                  label: 'QR Codes',
                  value: _statsLoading ? '...' : '$_claimedQr',
                  icon: Icons.qr_code_2_outlined,
                  color: CyberpunkColors.hotPink,
                ),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: ArcadeCard(
                neonColor: CyberpunkColors.neonGreen,
                title: 'Daily Intakes',
                icon: Icons.bar_chart_rounded,
                padding: const EdgeInsets.all(20),
                child: _statsLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _DailyIntakeChart(
                        dailyCounts: _dailyCounts(),
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
  });

  final Map<DateTime, int> dailyCounts;

  @override
  Widget build(BuildContext context) {
    final sortedKeys = dailyCounts.keys.toList()..sort();
    final values = sortedKeys.map((k) => dailyCounts[k]!.toDouble()).toList();
    final maxVal = values.isEmpty ? 1.0 : math.max(values.reduce(math.max), 1.0);
    final roundedMaxY = (maxVal * 1.3).ceilToDouble();

    return BarChart(
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
                  color: CyberpunkColors.voidBlack,
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
                  style: TextStyle(
                    color: CyberpunkColors.mistGray,
                    fontSize: 10,
                    fontFamily: 'RobotoMono',
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
                    style: TextStyle(
                      color: d == today ? CyberpunkColors.neonGreen : CyberpunkColors.mistGray,
                      fontSize: 10,
                      fontFamily: 'RobotoMono',
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
            color: CyberpunkColors.terminalGray.withOpacity(0.4),
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
                color: val > 0 ? CyberpunkColors.neonGreen : CyberpunkColors.terminalGray.withOpacity(0.3),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
              ),
            ],
          );
        }),
      ),
    );
  }
}

// Placeholder pages - these would be implemented similarly with cyberpunk styling
class _ProfilePageView extends StatelessWidget {
  const _ProfilePageView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'PROFILE PAGE',
        style: TextStyle(
          color: CyberpunkColors.neonGreen,
          fontSize: 12,
          fontFamily: 'PressStart2P',
        ),
      ),
    );
  }
}

class _NewIntakePageView extends StatelessWidget {
  const _NewIntakePageView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'NEW INTAKE PAGE',
        style: TextStyle(
          color: CyberpunkColors.neonCyan,
          fontSize: 12,
          fontFamily: 'PressStart2P',
        ),
      ),
    );
  }
}

class _QrCodesPageView extends StatelessWidget {
  final String centerId;
  const _QrCodesPageView({required this.centerId});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'QR CODES PAGE',
        style: TextStyle(
          color: CyberpunkColors.amber,
          fontSize: 12,
          fontFamily: 'PressStart2P',
        ),
      ),
    );
  }
}

class _HistoryPageView extends StatelessWidget {
  final String centerId;
  const _HistoryPageView({required this.centerId});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'HISTORY PAGE',
        style: TextStyle(
          color: CyberpunkColors.hotPink,
          fontSize: 12,
          fontFamily: 'PressStart2P',
        ),
      ),
    );
  }
}