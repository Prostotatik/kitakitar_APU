import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:kitakitar_mobile/providers/auth_provider.dart';
import 'package:kitakitar_mobile/theme/cyberpunk_theme.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
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
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PASSWORDS DO NOT MATCH', style: CyberpunkText.bodyText()),
          backgroundColor: CyberpunkColors.backgroundMoss,
        ),
      );
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.registerWithEmail(
      _nameController.text.trim(),
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (success && mounted) {
      context.go('/');
    } else if (mounted && authProvider.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.error!, style: CyberpunkText.bodyText()),
          backgroundColor: CyberpunkColors.backgroundMoss,
        ),
      );
    }
  }

  Future<void> _handleGoogleRegister() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.registerWithGoogle();

    if (success && mounted) {
      context.go('/');
    } else if (mounted && authProvider.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.error!, style: CyberpunkText.bodyText()),
          backgroundColor: CyberpunkColors.backgroundMoss,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('REGISTER', style: CyberpunkText.pixelHeading(fontSize: 12)),
        backgroundColor: CyberpunkColors.backgroundDeep,
        elevation: 0,
      ),
      body: CircuitGridBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Container(
                    decoration: BoxDecoration(
                      color: CyberpunkColors.backgroundMoss,
                      borderRadius: BorderRadius.circular(2),
                      border: Border.all(color: CyberpunkColors.neonGreen, width: 2),
                      boxShadow: CyberpunkGlow.greenGlow(intensity: 0.3),
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Logo with animated glow
                        AnimatedBuilder(
                          animation: _pulseAnimation,
                          builder: (context, child) {
                            return Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: CyberpunkColors.backgroundJungle,
                                borderRadius: BorderRadius.circular(2),
                                border: Border.all(color: CyberpunkColors.neonGreen, width: 2),
                                boxShadow: CyberpunkGlow.greenGlow(
                                  intensity: _pulseAnimation.value,
                                ),
                              ),
                              child: const Icon(
                                Icons.recycling_rounded,
                                size: 30,
                                color: CyberpunkColors.neonGreen,
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'CREATE ACCOUNT',
                          textAlign: TextAlign.center,
                          style: CyberpunkText.pixelHeading(
                            fontSize: 14,
                            color: CyberpunkColors.neonGreen,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'JOIN THE RECYCLING REVOLUTION',
                          textAlign: TextAlign.center,
                          style: CyberpunkText.pixelLabel(
                            fontSize: 7,
                            color: CyberpunkColors.electricLime,
                          ),
                        ),
                        const SizedBox(height: 24),
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
                        const SizedBox(height: 16),
                        Text(
                          'PASSWORD',
                          style: CyberpunkText.pixelLabel(
                            fontSize: 8,
                            color: CyberpunkColors.electricLime,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          style: CyberpunkText.bodyText(),
                          decoration: InputDecoration(
                            hintText: '••••••••',
                            hintStyle: CyberpunkText.bodyText(
                              color: CyberpunkColors.textSecondary.withOpacity(0.5),
                            ),
                            prefixIcon: const Icon(Icons.lock, color: CyberpunkColors.neonGreen),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                                color: CyberpunkColors.textSecondary,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'ENTER PASSWORD';
                            }
                            if (value.length < 6) {
                              return 'MIN 6 CHARACTERS';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'CONFIRM PASSWORD',
                          style: CyberpunkText.pixelLabel(
                            fontSize: 8,
                            color: CyberpunkColors.electricLime,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: _obscureConfirmPassword,
                          style: CyberpunkText.bodyText(),
                          decoration: InputDecoration(
                            hintText: '••••••••',
                            hintStyle: CyberpunkText.bodyText(
                              color: CyberpunkColors.textSecondary.withOpacity(0.5),
                            ),
                            prefixIcon: const Icon(Icons.lock_outline, color: CyberpunkColors.neonGreen),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirmPassword
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                                color: CyberpunkColors.textSecondary,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscureConfirmPassword = !_obscureConfirmPassword;
                                });
                              },
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'CONFIRM PASSWORD';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                        NeonButton(
                          label: 'CREATE ACCOUNT',
                          onPressed: authProvider.isLoading ? null : _handleRegister,
                          isLoading: authProvider.isLoading,
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: authProvider.isLoading ? null : _handleGoogleRegister,
                          icon: const Icon(Icons.g_mobiledata, color: CyberpunkColors.electricLime),
                          label: const Text('REGISTER WITH GOOGLE'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: CyberpunkColors.electricLime,
                            side: const BorderSide(color: CyberpunkColors.electricLime, width: 2),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Container(
                          height: 1,
                          color: CyberpunkColors.amberMoss,
                        ),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: () {
                            if (Navigator.canPop(context)) {
                              context.pop();
                            } else {
                              context.go('/login');
                            }
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: CyberpunkColors.neonGreen,
                          ),
                          child: Text(
                            'ALREADY HAVE AN ACCOUNT? SIGN IN',
                            style: CyberpunkText.pixelLabel(fontSize: 8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}