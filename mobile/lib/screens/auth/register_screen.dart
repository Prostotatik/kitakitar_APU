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

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
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
        const SnackBar(content: Text('PASSWORDS DO NOT MATCH')),
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
        SnackBar(content: Text(authProvider.error!)),
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
                color: CyberpunkColors.neonCyan,
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
                          title: 'NEW RECRUIT',
                          subtitle: 'CREATE YOUR IDENTITY',
                          iconSize: 48,
                        ),
                        const SizedBox(height: 32),

                        // Name field
                        NeonTextField(
                          controller: _nameController,
                          labelText: 'IDENTITY',
                          hintText: 'Your name',
                          prefixIcon: Icons.person,
                          neonColor: CyberpunkColors.neonCyan,
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
                        const SizedBox(height: 16),

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
                            if (value.length < 6) {
                              return 'Min 6 characters';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Confirm password field
                        NeonTextField(
                          controller: _confirmPasswordController,
                          labelText: 'CONFIRM PASSWORD',
                          hintText: '••••••••',
                          prefixIcon: Icons.lock_outline,
                          obscureText: _obscureConfirmPassword,
                          suffixIcon: _obscureConfirmPassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                          onToggleObscure: () {
                            setState(() {
                              _obscureConfirmPassword = !_obscureConfirmPassword;
                            });
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Confirm password';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 32),

                        // Register button
                        PixelButton(
                          text: authProvider.isLoading ? 'CREATING...' : 'INITIATE',
                          neonColor: CyberpunkColors.neonCyan,
                          isLoading: authProvider.isLoading,
                          onPressed: authProvider.isLoading ? null : _handleRegister,
                        ),
                        const SizedBox(height: 16),

                        // Google sign up
                        PixelButton(
                          text: 'GOOGLE ACCESS',
                          neonColor: CyberpunkColors.amber,
                          icon: Icons.g_mobiledata,
                          isOutlined: true,
                          onPressed: authProvider.isLoading ? null : _handleGoogleRegister,
                        ),
                        const SizedBox(height: 24),

                        // Back to login
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'ALREADY HAVE ACCESS?',
                              style: TextStyle(
                                color: CyberpunkColors.mistGray,
                                fontSize: 8,
                                fontFamily: 'PressStart2P',
                              ),
                            ),
                            const SizedBox(width: 12),
                            PixelButton(
                              text: 'LOGIN',
                              neonColor: CyberpunkColors.neonGreen,
                              fontSize: 10,
                              isOutlined: true,
                              onPressed: () {
                                if (Navigator.canPop(context)) {
                                  context.pop();
                                } else {
                                  context.go('/login');
                                }
                              },
                            ),
                          ],
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
}