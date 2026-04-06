import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// ╔═══════════════════════════════════════════════════════════════════════════════╗
/// ║  CYBERPUNK ARCADE x ECO-SUSTAINABILITY THEME                                 ║
/// ║  "Save the Planet © 2077"                                                    ║
/// ╚═══════════════════════════════════════════════════════════════════════════════╝

/// Color Palette - Neon Cyberpunk Eco
abstract class CyberpunkColors {
  // Deep dark backgrounds - forest atmosphere
  static const Color backgroundDeep = Color(0xFF050F05);      // Near-black forest green
  static const Color backgroundMoss = Color(0xFF0A1A08);      // Dark moss
  static const Color backgroundJungle = Color(0xFF145A1E);    // Deep jungle (panels/cards)

  // Neon accents
  static const Color neonGreen = Color(0xFF39FF6A);           // Light green - primary glows, CTAs
  static const Color electricLime = Color(0xFFD4FF3A);        // Light yellow - highlights, badges
  static const Color toxicGlow = Color(0xFFFF6A00);           // Orange - warnings, featured
  static const Color amberMoss = Color(0xFF8A7D00);           // Dark yellow - borders, accents

  // Supporting colors
  static const Color scanlineOverlay = Color(0xFF0A1A08);
  static const Color circuitGrid = Color(0xFF145A1E);

  // Text colors
  static const Color textPrimary = Color(0xFFE8F5E9);         // Light green-white
  static const Color textSecondary = Color(0xFF81C784);       // Muted green
  static const Color textGlow = Color(0xFF39FF6A);            // Neon green glow

  // Status colors
  static const Color successGlow = Color(0xFF39FF6A);
  static const Color warningGlow = Color(0xFFFF6A00);
  static const Color errorGlow = Color(0xFFFF3333);
  static const Color infoGlow = Color(0xFF39D4FF);
}

/// Neon Glow Effects - Pre-defined shadows
abstract class CyberpunkGlow {
  // Green neon glow
  static List<BoxShadow> greenGlow({double intensity = 1.0}) => [
    BoxShadow(
      color: CyberpunkColors.neonGreen.withOpacity(0.3 * intensity),
      blurRadius: 8 * intensity,
      spreadRadius: 1 * intensity,
    ),
    BoxShadow(
      color: CyberpunkColors.neonGreen.withOpacity(0.15 * intensity),
      blurRadius: 20 * intensity,
      spreadRadius: 3 * intensity,
    ),
  ];

  // Lime neon glow
  static List<BoxShadow> limeGlow({double intensity = 1.0}) => [
    BoxShadow(
      color: CyberpunkColors.electricLime.withOpacity(0.3 * intensity),
      blurRadius: 6 * intensity,
      spreadRadius: 1 * intensity,
    ),
  ];

  // Orange toxic glow
  static List<BoxShadow> orangeGlow({double intensity = 1.0}) => [
    BoxShadow(
      color: CyberpunkColors.toxicGlow.withOpacity(0.3 * intensity),
      blurRadius: 8 * intensity,
      spreadRadius: 1 * intensity,
    ),
    BoxShadow(
      color: CyberpunkColors.toxicGlow.withOpacity(0.15 * intensity),
      blurRadius: 16 * intensity,
      spreadRadius: 2 * intensity,
    ),
  ];

  // Soft inner glow for cards
  static List<BoxShadow> innerGlow() => [
    BoxShadow(
      color: CyberpunkColors.neonGreen.withOpacity(0.05),
      blurRadius: 0,
      spreadRadius: 0,
    ),
  ];

  // Text shadow for neon headings
  static List<Shadow> textGlow({Color color = CyberpunkColors.neonGreen, double intensity = 1.0}) => [
    Shadow(
      color: color.withOpacity(0.8 * intensity),
      blurRadius: 4 * intensity,
    ),
    Shadow(
      color: color.withOpacity(0.4 * intensity),
      blurRadius: 12 * intensity,
    ),
  ];
}

/// Typography - Pixel/Retro Monospace Style
abstract class CyberpunkText {
  // Note: The actual font family will be set via theme
  static const String pixelFontFamily = 'PressStart2P';
  static const String fallbackFontFamily = 'Roboto';

  static TextStyle pixelHeading({
    double fontSize = 16,
    Color color = CyberpunkColors.neonGreen,
    bool glow = true,
  }) => TextStyle(
    fontFamily: pixelFontFamily,
    fontSize: fontSize,
    fontWeight: FontWeight.w400,
    color: color,
    letterSpacing: 1.5,
    shadows: glow ? CyberpunkGlow.textGlow(color: color) : null,
  );

  static TextStyle pixelLabel({
    double fontSize = 10,
    Color color = CyberpunkColors.electricLime,
    bool glow = false,
  }) => TextStyle(
    fontFamily: pixelFontFamily,
    fontSize: fontSize,
    fontWeight: FontWeight.w400,
    color: color,
    letterSpacing: 1.0,
    shadows: glow ? CyberpunkGlow.textGlow(color: color, intensity: 0.5) : null,
  );

  static TextStyle bodyText({
    double fontSize = 14,
    Color color = CyberpunkColors.textPrimary,
  }) => TextStyle(
    fontFamily: fallbackFontFamily,
    fontSize: fontSize,
    fontWeight: FontWeight.w400,
    color: color,
  );

  static TextStyle bodyBold({
    double fontSize = 14,
    Color color = CyberpunkColors.textPrimary,
  }) => TextStyle(
    fontFamily: fallbackFontFamily,
    fontSize: fontSize,
    fontWeight: FontWeight.w600,
    color: color,
  );
}

/// Custom Painter for Scanline Overlay Effect
class ScanlineOverlay extends StatelessWidget {
  final Widget child;
  final double opacity;

  const ScanlineOverlay({
    super.key,
    required this.child,
    this.opacity = 0.03,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Positioned.fill(
          child: CustomPaint(
            painter: _ScanlinePainter(opacity: opacity),
          ),
        ),
      ],
    );
  }
}

class _ScanlinePainter extends CustomPainter {
  final double opacity;

  _ScanlinePainter({required this.opacity});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = CyberpunkColors.scanlineOverlay.withOpacity(opacity)
      ..strokeWidth = 1;

    for (double y = 0; y < size.height; y += 3) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Circuit Grid Background Pattern
class CircuitGridBackground extends StatelessWidget {
  final Widget child;

  const CircuitGridBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            CyberpunkColors.backgroundDeep,
            CyberpunkColors.backgroundMoss,
            CyberpunkColors.backgroundDeep,
          ],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      child: CustomPaint(
        painter: _CircuitGridPainter(),
        child: child,
      ),
    );
  }
}

class _CircuitGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = CyberpunkColors.circuitGrid.withOpacity(0.15)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    const gridSize = 40.0;

    // Draw vertical lines
    for (double x = 0; x < size.width; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Draw horizontal lines
    for (double y = 0; y < size.height; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    // Add some circuit nodes at intersections
    final nodePaint = Paint()
      ..color = CyberpunkColors.neonGreen.withOpacity(0.1)
      ..style = PaintingStyle.fill;

    for (double x = 0; x < size.width; x += gridSize * 2) {
      for (double y = 0; y < size.height; y += gridSize * 2) {
        canvas.drawCircle(Offset(x, y), 2, nodePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// ═══════════════════════════════════════════════════════════════════════════════
/// CYBERPUNK THEME DATA
/// ═══════════════════════════════════════════════════════════════════════════════

ThemeData buildCyberpunkTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: 'Roboto',
  );

  return base.copyWith(
    // Color Scheme
    colorScheme: base.colorScheme.copyWith(
      primary: CyberpunkColors.neonGreen,
      secondary: CyberpunkColors.electricLime,
      tertiary: CyberpunkColors.toxicGlow,
      surface: CyberpunkColors.backgroundMoss,
      error: CyberpunkColors.errorGlow,
      onPrimary: CyberpunkColors.backgroundDeep,
      onSecondary: CyberpunkColors.backgroundDeep,
      onSurface: CyberpunkColors.textPrimary,
      onError: CyberpunkColors.textPrimary,
    ),

    // Scaffold
    scaffoldBackgroundColor: CyberpunkColors.backgroundDeep,

    // AppBar
    appBarTheme: AppBarTheme(
      backgroundColor: CyberpunkColors.backgroundDeep,
      foregroundColor: CyberpunkColors.neonGreen,
      elevation: 0,
      centerTitle: true,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      titleTextStyle: CyberpunkText.pixelHeading(fontSize: 14),
      iconTheme: const IconThemeData(color: CyberpunkColors.neonGreen),
    ),

    // Cards
    cardTheme: CardThemeData(
      color: CyberpunkColors.backgroundMoss,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(2), // Sharp pixel corners
        side: const BorderSide(
          color: CyberpunkColors.neonGreen,
          width: 1.5,
        ),
      ),
    ),

    // Elevated Buttons
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: CyberpunkColors.backgroundJungle,
        foregroundColor: CyberpunkColors.neonGreen,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(2),
          side: const BorderSide(color: CyberpunkColors.neonGreen, width: 2),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        textStyle: CyberpunkText.pixelLabel(fontSize: 10),
      ),
    ),

    // Filled Buttons
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: CyberpunkColors.neonGreen,
        foregroundColor: CyberpunkColors.backgroundDeep,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(2),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        textStyle: CyberpunkText.pixelLabel(fontSize: 10),
      ),
    ),

    // Outlined Buttons
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: CyberpunkColors.neonGreen,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(2),
        ),
        side: const BorderSide(color: CyberpunkColors.neonGreen, width: 2),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        textStyle: CyberpunkText.pixelLabel(fontSize: 10),
      ),
    ),

    // Text Buttons
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: CyberpunkColors.electricLime,
        textStyle: CyberpunkText.bodyText(fontSize: 12),
      ),
    ),

    // Input Decoration
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: CyberpunkColors.backgroundMoss,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(2),
        borderSide: const BorderSide(color: CyberpunkColors.amberMoss, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(2),
        borderSide: const BorderSide(color: CyberpunkColors.amberMoss, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(2),
        borderSide: const BorderSide(color: CyberpunkColors.neonGreen, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(2),
        borderSide: const BorderSide(color: CyberpunkColors.errorGlow, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(2),
        borderSide: const BorderSide(color: CyberpunkColors.errorGlow, width: 2),
      ),
      labelStyle: CyberpunkText.pixelLabel(fontSize: 8, color: CyberpunkColors.textSecondary),
      hintStyle: CyberpunkText.bodyText(color: CyberpunkColors.textSecondary.withOpacity(0.6)),
    ),

    // Text Theme
    textTheme: base.textTheme.copyWith(
      displayLarge: CyberpunkText.pixelHeading(fontSize: 24),
      displayMedium: CyberpunkText.pixelHeading(fontSize: 20),
      displaySmall: CyberpunkText.pixelHeading(fontSize: 16),
      headlineLarge: CyberpunkText.pixelHeading(fontSize: 18),
      headlineMedium: CyberpunkText.pixelHeading(fontSize: 14),
      headlineSmall: CyberpunkText.pixelHeading(fontSize: 12),
      titleLarge: CyberpunkText.bodyBold(fontSize: 18),
      titleMedium: CyberpunkText.bodyBold(fontSize: 16),
      titleSmall: CyberpunkText.bodyBold(fontSize: 14),
      bodyLarge: CyberpunkText.bodyText(fontSize: 16),
      bodyMedium: CyberpunkText.bodyText(fontSize: 14),
      bodySmall: CyberpunkText.bodyText(fontSize: 12, color: CyberpunkColors.textSecondary),
      labelLarge: CyberpunkText.pixelLabel(fontSize: 10),
      labelMedium: CyberpunkText.pixelLabel(fontSize: 8),
      labelSmall: CyberpunkText.pixelLabel(fontSize: 6),
    ),

    // Icon Theme
    iconTheme: const IconThemeData(
      color: CyberpunkColors.neonGreen,
      size: 24,
    ),

    // Progress Indicators
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: CyberpunkColors.neonGreen,
      linearTrackColor: CyberpunkColors.backgroundJungle,
      circularTrackColor: CyberpunkColors.backgroundJungle,
    ),

    // Floating Action Button
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: CyberpunkColors.neonGreen,
      foregroundColor: CyberpunkColors.backgroundDeep,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(2),
        side: const BorderSide(color: CyberpunkColors.electricLime, width: 2),
      ),
    ),

    // Bottom Navigation Bar
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: CyberpunkColors.backgroundDeep,
      selectedItemColor: CyberpunkColors.neonGreen,
      unselectedItemColor: CyberpunkColors.textSecondary,
      selectedLabelStyle: CyberpunkText.pixelLabel(fontSize: 8),
      unselectedLabelStyle: CyberpunkText.pixelLabel(fontSize: 8, color: CyberpunkColors.textSecondary),
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),

    // Navigation Bar (Material 3)
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: CyberpunkColors.backgroundDeep,
      indicatorColor: CyberpunkColors.neonGreen.withOpacity(0.2),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return CyberpunkText.pixelLabel(fontSize: 8, color: CyberpunkColors.neonGreen);
        }
        return CyberpunkText.pixelLabel(fontSize: 8, color: CyberpunkColors.textSecondary);
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: CyberpunkColors.neonGreen);
        }
        return const IconThemeData(color: CyberpunkColors.textSecondary);
      }),
    ),

    // Divider
    dividerTheme: const DividerThemeData(
      color: CyberpunkColors.amberMoss,
      thickness: 1,
    ),

    // Chip Theme
    chipTheme: ChipThemeData(
      backgroundColor: CyberpunkColors.backgroundJungle,
      selectedColor: CyberpunkColors.neonGreen,
      labelStyle: CyberpunkText.pixelLabel(fontSize: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(2),
        side: const BorderSide(color: CyberpunkColors.neonGreen, width: 1),
      ),
    ),

    // Snackbar
    snackBarTheme: SnackBarThemeData(
      backgroundColor: CyberpunkColors.backgroundMoss,
      contentTextStyle: CyberpunkText.bodyText(),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(2),
        side: const BorderSide(color: CyberpunkColors.neonGreen, width: 1),
      ),
      behavior: SnackBarBehavior.floating,
    ),

    // Dialog
    dialogTheme: DialogThemeData(
      backgroundColor: CyberpunkColors.backgroundMoss,
      titleTextStyle: CyberpunkText.pixelHeading(fontSize: 14),
      contentTextStyle: CyberpunkText.bodyText(),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(2),
        side: const BorderSide(color: CyberpunkColors.neonGreen, width: 2),
      ),
    ),

    // Bottom Sheet
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: CyberpunkColors.backgroundMoss,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(2)),
        side: BorderSide(color: CyberpunkColors.neonGreen, width: 2),
      ),
    ),
  );
}

/// ═══════════════════════════════════════════════════════════════════════════════
/// CYBERPUNK WIDGETS - Reusable Styled Components
/// ═══════════════════════════════════════════════════════════════════════════════

/// Neon Button with glow effect
class NeonButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final Color glowColor;
  final bool isPrimary;
  final IconData? icon;
  final bool isLoading;

  const NeonButton({
    super.key,
    required this.label,
    this.onPressed,
    this.glowColor = CyberpunkColors.neonGreen,
    this.isPrimary = true,
    this.icon,
    this.isLoading = false,
  });

  @override
  State<NeonButton> createState() => _NeonButtonState();
}

class _NeonButtonState extends State<NeonButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final buttonContent = widget.isLoading
        ? const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(CyberpunkColors.backgroundDeep),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: 16),
                const SizedBox(width: 8),
              ],
              Text(widget.label.toUpperCase()),
            ],
          );

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            boxShadow: widget.onPressed != null
                ? CyberpunkGlow.greenGlow(intensity: _pulseAnimation.value * 0.5)
                : null,
          ),
          child: widget.isPrimary
              ? ElevatedButton(
                  onPressed: widget.isLoading ? null : widget.onPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.glowColor,
                    foregroundColor: CyberpunkColors.backgroundDeep,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(2),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    textStyle: CyberpunkText.pixelLabel(fontSize: 10),
                  ),
                  child: buttonContent,
                )
              : OutlinedButton(
                  onPressed: widget.isLoading ? null : widget.onPressed,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: widget.glowColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(2),
                    ),
                    side: BorderSide(color: widget.glowColor, width: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    textStyle: CyberpunkText.pixelLabel(fontSize: 10),
                  ),
                  child: buttonContent,
                ),
        );
      },
    );
  }
}

/// Cyberpunk Card with neon border
class CyberpunkCard extends StatelessWidget {
  final Widget child;
  final Color borderColor;
  final Color? backgroundColor;
  final double borderWidth;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final Widget? trailing;

  const CyberpunkCard({
    super.key,
    required this.child,
    this.borderColor = CyberpunkColors.neonGreen,
    this.backgroundColor,
    this.borderWidth = 1.5,
    this.padding,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor ?? CyberpunkColors.backgroundMoss,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: borderColor, width: borderWidth),
        boxShadow: CyberpunkGlow.innerGlow(),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(2),
          child: Padding(
            padding: padding ?? const EdgeInsets.all(12),
            child: trailing != null
                ? Row(children: [Expanded(child: child), trailing!])
                : child,
          ),
        ),
      ),
    );
  }
}

/// Pixel-style Status Bar / HUD
class ArcadeHudBar extends StatelessWidget {
  final String? leftText;
  final String? centerText;
  final String? rightText;
  final Color accentColor;

  const ArcadeHudBar({
    super.key,
    this.leftText,
    this.centerText,
    this.rightText,
    this.accentColor = CyberpunkColors.neonGreen,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: CyberpunkColors.backgroundDeep,
        border: Border(
          top: BorderSide(color: accentColor, width: 1),
          bottom: BorderSide(color: accentColor, width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (leftText != null)
            Text(
              leftText!,
              style: CyberpunkText.pixelLabel(fontSize: 8, color: accentColor),
            ),
          if (centerText != null)
            Text(
              centerText!,
              style: CyberpunkText.pixelLabel(fontSize: 8, color: accentColor),
            ),
          if (rightText != null)
            Text(
              rightText!,
              style: CyberpunkText.pixelLabel(fontSize: 8, color: accentColor),
            ),
        ],
      ),
    );
  }
}

/// Neon Heading with glow effect
class NeonHeading extends StatelessWidget {
  final String text;
  final double fontSize;
  final Color color;
  final TextAlign textAlign;

  const NeonHeading({
    super.key,
    required this.text,
    this.fontSize = 16,
    this.color = CyberpunkColors.neonGreen,
    this.textAlign = TextAlign.center,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      textAlign: textAlign,
      style: CyberpunkText.pixelHeading(
        fontSize: fontSize,
        color: color,
        glow: true,
      ),
    );
  }
}

/// Recycling/Eco Badge
class EcoBadge extends StatelessWidget {
  final IconData icon;
  final String? label;
  final Color color;
  final double size;

  const EcoBadge({
    super.key,
    required this.icon,
    this.label,
    this.color = CyberpunkColors.neonGreen,
    this.size = 24,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: CyberpunkColors.backgroundJungle.withOpacity(0.5),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: color, width: 1),
      ),
      child: Icon(icon, color: color, size: size),
    );
  }
}

/// Animated Neon Border
class AnimatedNeonBorder extends StatefulWidget {
  final Widget child;
  final Color borderColor;
  final Duration animationDuration;

  const AnimatedNeonBorder({
    super.key,
    required this.child,
    this.borderColor = CyberpunkColors.neonGreen,
    this.animationDuration = const Duration(milliseconds: 2000),
  });

  @override
  State<AnimatedNeonBorder> createState() => _AnimatedNeonBorderState();
}

class _AnimatedNeonBorderState extends State<AnimatedNeonBorder>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.3, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            boxShadow: [
              BoxShadow(
                color: widget.borderColor.withOpacity(_animation.value * 0.5),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
          child: widget.child,
        );
      },
    );
  }
}