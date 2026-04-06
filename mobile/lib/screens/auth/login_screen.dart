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

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
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
        SnackBar(content: Text(authProvider.error!)),
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
        SnackBar(content: Text(authProvider.error!)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          color: CyberpunkColors.voidBlack,
        ),
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
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Logo
                        const CyberpunkLogoHeader(
                          title: 'KITAKITAR',
                          subtitle: 'AI-POWERED RECYCLING',
                          iconSize: 56,
                        ),
                        const SizedBox(height: 48),

                        // Email field
                        NeonTextField(
                          controller: _emailController,
                          labelText: 'EMAIL',
                          hintText: 'user@example.com',
                          prefixIcon: Icons.email,
                          keyboardType: TextInputType.emailAddress,
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
                        const SizedBox(height: 20),

                        // Password field
                        NeonTextField(
                          controller: _passwordController,
                          labelText: 'PASSWORD',
                          hintText: '••••••••',
                          prefixIcon: Icons.lock,
                          obscureText: _obscurePassword,
                          suffixIcon: _obscurePassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                          onToggleObscure: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Enter password';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 32),

                        // Login button
                        PixelButton(
                          text: authProvider.isLoading ? 'LOADING...' : 'ENTER SYSTEM',
                          neonColor: CyberpunkColors.neonGreen,
                          isLoading: authProvider.isLoading,
                          onPressed: authProvider.isLoading ? null : _handleLogin,
                        ),
                        const SizedBox(height: 16),

                        // Google sign in
                        PixelButton(
                          text: 'GOOGLE ACCESS',
                          neonColor: CyberpunkColors.neonCyan,
                          icon: Icons.g_mobiledata,
                          isOutlined: true,
                          onPressed: authProvider.isLoading ? null : _handleGoogleLogin,
                        ),
                        const SizedBox(height: 32),

                        // Divider with scanline effect
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
                              padding: const EdgeInsets.symmetric(horizontal: 16),
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

                        // Register and Forgot password links
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            PixelButton(
                              text: 'NEW USER',
                              neonColor: CyberpunkColors.amber,
                              fontSize: 10,
                              isOutlined: true,
                              onPressed: () => context.push('/register'),
                            ),
                            const SizedBox(width: 16),
                            PixelButton(
                              text: 'RECOVER',
                              neonColor: CyberpunkColors.hotPink,
                              fontSize: 10,
                              isOutlined: true,
                              onPressed: () => context.push('/forgot-password'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 48),

                        // Footer
                        ArcadeHudFooter(ecoCredits: 0, greenLevel: 1),
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
}