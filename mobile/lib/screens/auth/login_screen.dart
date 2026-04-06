import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:kitakitar_mobile/providers/auth_provider.dart';
import 'package:kitakitar_mobile/theme/cyberpunk_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
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
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.signInWithEmail(
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

  Future<void> _handleGoogleLogin() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.signInWithGoogle();

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
                              width: 80,
                              height: 80,
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
                                size: 40,
                                color: CyberpunkColors.neonGreen,
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'KITAKITAR',
                          textAlign: TextAlign.center,
                          style: CyberpunkText.pixelHeading(
                            fontSize: 18,
                            color: CyberpunkColors.neonGreen,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'RECYCLING REWARDS SYSTEM',
                          textAlign: TextAlign.center,
                          style: CyberpunkText.pixelLabel(
                            fontSize: 8,
                            color: CyberpunkColors.electricLime,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const ArcadeHudBar(
                          leftText: '♻ ECO',
                          centerText: 'ONLINE',
                          rightText: '2077',
                        ),
                        const SizedBox(height: 32),
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
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                        NeonButton(
                          label: 'SIGN IN',
                          onPressed: authProvider.isLoading ? null : _handleLogin,
                          isLoading: authProvider.isLoading,
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: authProvider.isLoading ? null : _handleGoogleLogin,
                          icon: const Icon(Icons.g_mobiledata, color: CyberpunkColors.electricLime),
                          label: const Text('SIGN IN WITH GOOGLE'),
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
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            TextButton(
                              onPressed: () => context.push('/register'),
                              style: TextButton.styleFrom(
                                foregroundColor: CyberpunkColors.neonGreen,
                              ),
                              child: Text('REGISTER', style: CyberpunkText.pixelLabel(fontSize: 8)),
                            ),
                            Text(' | ', style: CyberpunkText.bodyText(color: CyberpunkColors.textSecondary)),
                            TextButton(
                              onPressed: () => context.push('/forgot-password'),
                              style: TextButton.styleFrom(
                                foregroundColor: CyberpunkColors.electricLime,
                              ),
                              child: Text('FORGOT PASSWORD?', style: CyberpunkText.pixelLabel(fontSize: 8)),
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
        ),
      ),
    );
  }
}