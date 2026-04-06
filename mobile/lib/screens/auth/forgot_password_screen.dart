import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:kitakitar_mobile/providers/auth_provider.dart';
import 'package:kitakitar_mobile/theme/cyberpunk_theme.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _emailSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleResetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.sendPasswordReset(_emailController.text.trim());

    if (mounted) {
      setState(() {
        _emailSent = true;
      });
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
                color: CyberpunkColors.hotPink,
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
                        if (_emailSent) ...[
                          // Success state
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: CyberpunkColors.darkMatter,
                              border: Border.all(
                                color: CyberpunkColors.neonGreen,
                                width: 3,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: NeonGlow.greenGlow(blur: 20),
                            ),
                            child: const Icon(
                              Icons.check_circle,
                              size: 48,
                              color: CyberpunkColors.neonGreen,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'TRANSMISSION SENT',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: CyberpunkColors.neonGreen,
                              fontSize: 16,
                              fontFamily: 'PressStart2P',
                              fontWeight: FontWeight.w700,
                              shadows: NeonGlow.greenTextGlow(),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Check ${_emailController.text.trim()} for recovery instructions.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: CyberpunkColors.mistGray,
                              fontSize: 12,
                              fontFamily: 'RobotoMono',
                            ),
                          ),
                          const SizedBox(height: 32),
                          PixelButton(
                            text: 'RETURN',
                            neonColor: CyberpunkColors.neonGreen,
                            onPressed: () {
                              if (Navigator.canPop(context)) {
                                context.pop();
                              } else {
                                context.go('/login');
                              }
                            },
                          ),
                        ] else ...[
                          // Logo
                          const CyberpunkLogoHeader(
                            title: 'RECOVERY',
                            subtitle: 'RESTORE YOUR ACCESS',
                            iconSize: 48,
                          ),
                          const SizedBox(height: 32),

                          // Description
                          Text(
                            'ENTER YOUR EMAIL TO RECEIVE RECOVERY INSTRUCTIONS',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: CyberpunkColors.mistGray,
                              fontSize: 10,
                              fontFamily: 'PressStart2P',
                            ),
                          ),
                          const SizedBox(height: 32),

                          // Email field
                          NeonTextField(
                            controller: _emailController,
                            labelText: 'EMAIL',
                            hintText: 'user@example.com',
                            prefixIcon: Icons.email,
                            keyboardType: TextInputType.emailAddress,
                            neonColor: CyberpunkColors.hotPink,
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
                          const SizedBox(height: 24),

                          // Submit button
                          PixelButton(
                            text: authProvider.isLoading ? 'SENDING...' : 'SEND RECOVERY',
                            neonColor: CyberpunkColors.hotPink,
                            isLoading: authProvider.isLoading,
                            onPressed: authProvider.isLoading ? null : _handleResetPassword,
                          ),
                          const SizedBox(height: 16),

                          // Back to login
                          PixelButton(
                            text: 'BACK TO LOGIN',
                            neonColor: CyberpunkColors.neonGreen,
                            isOutlined: true,
                            fontSize: 10,
                            onPressed: () {
                              if (Navigator.canPop(context)) {
                                context.pop();
                              } else {
                                context.go('/login');
                              }
                            },
                          ),
                        ],
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