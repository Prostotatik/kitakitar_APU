import 'package:flutter/material.dart';

/// ╔═══════════════════════════════════════════════════════════════════════════════╗
/// ║  CYBERPUNK ARCADE x ECO-SUSTAINABILITY THEME (CENTER WEB)                    ║
/// ║  "Save the Planet © 2077"                                                    ║
/// ╚═══════════════════════════════════════════════════════════════════════════════╝

/// Color Palette - Neon Cyberpunk Eco
abstract class CyberpunkColors {
  // Deep dark backgrounds - forest atmosphere
  static const Color backgroundDeep = Color(0xFF050F05);
  static const Color backgroundMoss = Color(0xFF0A1A08);
  static const Color backgroundJungle = Color(0xFF145A1E);

  // Neon accents
  static const Color neonGreen = Color(0xFF39FF6A);
  static const Color electricLime = Color(0xFFD4FF3A);
  static const Color toxicGlow = Color(0xFFFF6A00);
  static const Color amberMoss = Color(0xFF8A7D00);

  // Text colors
  static const Color textPrimary = Color(0xFFE8F5E9);
  static const Color textSecondary = Color(0xFF81C784);
  static const Color textGlow = Color(0xFF39FF6A);

  // Status colors
  static const Color successGlow = Color(0xFF39FF6A);
  static const Color warningGlow = Color(0xFFFF6A00);
  static const Color errorGlow = Color(0xFFFF3333);
  static const Color infoGlow = Color(0xFF39D4FF);
}

/// Neon Glow Effects - Pre-defined shadows
abstract class CyberpunkGlow {
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

  static List<BoxShadow> limeGlow({double intensity = 1.0}) => [
    BoxShadow(
      color: CyberpunkColors.electricLime.withOpacity(0.3 * intensity),
      blurRadius: 6 * intensity,
      spreadRadius: 1 * intensity,
    ),
  ];

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

  static List<BoxShadow> innerGlow() => [
    BoxShadow(
      color: CyberpunkColors.neonGreen.withOpacity(0.05),
      blurRadius: 0,
      spreadRadius: 0,
    ),
  ];

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

/// Typography
abstract class CyberpunkText {
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
      ..color = CyberpunkColors.backgroundJungle.withOpacity(0.15)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    const gridSize = 40.0;

    for (double x = 0; x < size.width; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    for (double y = 0; y < size.height; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

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

/// Build Cyberpunk Theme for Web
ThemeData buildCyberpunkTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: 'Roboto',
  );

  return base.copyWith(
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

    scaffoldBackgroundColor: CyberpunkColors.backgroundDeep,

    appBarTheme: AppBarTheme(
      backgroundColor: CyberpunkColors.backgroundDeep,
      foregroundColor: CyberpunkColors.neonGreen,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: CyberpunkText.pixelHeading(fontSize: 14),
      iconTheme: const IconThemeData(color: CyberpunkColors.neonGreen),
    ),

    cardTheme: CardThemeData(
      color: CyberpunkColors.backgroundMoss,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(2),
        side: const BorderSide(
          color: CyberpunkColors.neonGreen,
          width: 1.5,
        ),
      ),
    ),

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

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: CyberpunkColors.electricLime,
        textStyle: CyberpunkText.bodyText(fontSize: 12),
      ),
    ),

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

    iconTheme: const IconThemeData(
      color: CyberpunkColors.neonGreen,
      size: 24,
    ),

    dividerTheme: const DividerThemeData(
      color: CyberpunkColors.amberMoss,
      thickness: 1,
    ),

    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: CyberpunkColors.backgroundDeep,
      selectedIconTheme: const IconThemeData(color: CyberpunkColors.neonGreen),
      unselectedIconTheme: const IconThemeData(color: CyberpunkColors.textSecondary),
      selectedLabelTextStyle: CyberpunkText.pixelLabel(fontSize: 8, color: CyberpunkColors.neonGreen),
      unselectedLabelTextStyle: CyberpunkText.pixelLabel(fontSize: 8, color: CyberpunkColors.textSecondary),
    ),

    snackBarTheme: SnackBarThemeData(
      backgroundColor: CyberpunkColors.backgroundMoss,
      contentTextStyle: CyberpunkText.bodyText(),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(2),
        side: const BorderSide(color: CyberpunkColors.neonGreen, width: 1),
      ),
      behavior: SnackBarBehavior.floating,
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: CyberpunkColors.backgroundMoss,
      titleTextStyle: CyberpunkText.pixelHeading(fontSize: 14),
      contentTextStyle: CyberpunkText.bodyText(),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(2),
        side: const BorderSide(color: CyberpunkColors.neonGreen, width: 2),
      ),
    ),
  );
}

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

/// Arcade HUD Bar
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