import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// CYBERPUNK ARCADE × ECO SUSTAINABILITY THEME
/// A retro-futuristic pixel art aesthetic fused with nature reclaiming technology
/// ═══════════════════════════════════════════════════════════════════════════

class CyberpunkColors {
  // Core dark backgrounds
  static const Color voidBlack = Color(0xFF0a0a0f);
  static const Color darkMatter = Color(0xFF12121a);
  static const Color circuitBoard = Color(0xFF1a1a25);
  static const Color terminalGray = Color(0xFF252530);
  static const Color oxidizedMetal = Color(0xFF2d2d3a);

  // Neon spectrum - the lifeblood of cyberpunk
  static const Color neonGreen = Color(0xFF00ff88);
  static const Color toxicGreen = Color(0xFF39ff14);
  static const Color matrixGreen = Color(0xFF00ff41);
  static const Color ecoGlow = Color(0xFF00ffa3);

  // Accent neons
  static const Color neonCyan = Color(0xFF00f5ff);
  static const Color electricBlue = Color(0xFF00d4ff);
  static const Color synthwavePink = Color(0xFFFF00FF);
  static const Color hotPink = Color(0xFFFF1493);
  static const Color amber = Color(0xFFFFaa00);
  static const Color sunsetOrange = Color(0xFFFF6B35);

  // Nature fusion - organic meets digital
  static const Color forestGlow = Color(0xFF228B22);
  static const Color leafVeridian = Color(0xFF40855a);
  static const Color moss = Color(0xFF6B8E23);
  static const Color earthBrown = Color(0xFF8B4513);

  // Text colors
  static const Color pureWhite = Color(0xFFFFFFFF);
  static const Color ghostWhite = Color(0xFFF0F0F0);
  static const Color mistGray = Color(0xFFB0B0B0);
  static const Color dimGray = Color(0xFF707080);
  static const Color shadowGray = Color(0xFF404050);
}

/// Neon glow effects for text and containers
class NeonGlow {
  static List<BoxShadow> greenGlow({double blur = 12, double spread = 0}) => [
    BoxShadow(
      color: CyberpunkColors.neonGreen.withOpacity(0.6),
      blurRadius: blur,
      spreadRadius: spread,
    ),
    BoxShadow(
      color: CyberpunkColors.neonGreen.withOpacity(0.3),
      blurRadius: blur * 2,
      spreadRadius: spread,
    ),
  ];

  static List<BoxShadow> cyanGlow({double blur = 12}) => [
    BoxShadow(
      color: CyberpunkColors.neonCyan.withOpacity(0.6),
      blurRadius: blur,
    ),
    BoxShadow(
      color: CyberpunkColors.neonCyan.withOpacity(0.3),
      blurRadius: blur * 2,
    ),
  ];

  static List<BoxShadow> pinkGlow({double blur = 12}) => [
    BoxShadow(
      color: CyberpunkColors.hotPink.withOpacity(0.6),
      blurRadius: blur,
    ),
    BoxShadow(
      color: CyberpunkColors.hotPink.withOpacity(0.3),
      blurRadius: blur * 2,
    ),
  ];

  static List<Shadow> textGlow(Color color, {double blur = 8}) => [
    Shadow(color: color.withOpacity(0.8), blurRadius: blur),
    Shadow(color: color.withOpacity(0.5), blurRadius: blur * 2),
  ];

  static List<Shadow> greenTextGlow() => textGlow(CyberpunkColors.neonGreen);
  static List<Shadow> cyanTextGlow() => textGlow(CyberpunkColors.neonCyan);
}

/// Custom painter for scanline overlay effect
class ScanlinePainter extends CustomPainter {
  final Color color;
  final double opacity;

  ScanlinePainter({
    this.color = CyberpunkColors.neonGreen,
    this.opacity = 0.03,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color.withOpacity(opacity);

    for (var y = 0.0; y < size.height; y += 3) {
      canvas.drawRect(
        Rect.fromLTWH(0, y, size.width, 1),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Custom painter for circuit grid overlay
class CircuitGridPainter extends CustomPainter {
  final Color color;
  final double gridSize;

  CircuitGridPainter({
    this.color = CyberpunkColors.neonGreen,
    this.gridSize = 40,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.05)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    // Vertical lines
    for (var x = 0.0; x < size.width; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Horizontal lines
    for (var y = 0.0; y < size.height; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    // Circuit nodes
    final nodePaint = Paint()
      ..color = color.withOpacity(0.1)
      ..style = PaintingStyle.fill;

    for (var x = gridSize; x < size.width; x += gridSize * 2) {
      for (var y = gridSize; y < size.height; y += gridSize * 2) {
        canvas.drawCircle(Offset(x, y), 2, nodePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Animated neon border container
class NeonBorderContainer extends StatefulWidget {
  final Widget child;
  final Color borderColor;
  final double borderWidth;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final bool animate;
  final Duration animationDuration;

  const NeonBorderContainer({
    super.key,
    required this.child,
    this.borderColor = CyberpunkColors.neonGreen,
    this.borderWidth = 2,
    this.borderRadius = 4,
    this.padding = const EdgeInsets.all(16),
    this.margin = EdgeInsets.zero,
    this.animate = true,
    this.animationDuration = const Duration(milliseconds: 1500),
  });

  @override
  State<NeonBorderContainer> createState() => _NeonBorderContainerState();
}

class _NeonBorderContainerState extends State<NeonBorderContainer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: widget.margin,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return Container(
            padding: widget.padding,
            decoration: BoxDecoration(
              color: CyberpunkColors.darkMatter,
              border: Border.all(
                color: widget.borderColor,
                width: widget.borderWidth,
              ),
              borderRadius: BorderRadius.circular(widget.borderRadius),
              boxShadow: widget.animate
                  ? [
                      BoxShadow(
                        color: widget.borderColor.withOpacity(_animation.value * 0.6),
                        blurRadius: 8,
                        spreadRadius: 0,
                      ),
                      BoxShadow(
                        color: widget.borderColor.withOpacity(_animation.value * 0.3),
                        blurRadius: 16,
                        spreadRadius: 0,
                      ),
                    ]
                  : NeonGlow.greenGlow(),
            ),
            child: widget.child,
          );
        },
      ),
    );
  }
}

/// Pixel-style arcade button
class PixelButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final Color neonColor;
  final bool isLoading;
  final bool isOutlined;
  final double fontSize;
  final IconData? icon;

  const PixelButton({
    super.key,
    required this.text,
    this.onPressed,
    this.neonColor = CyberpunkColors.neonGreen,
    this.isLoading = false,
    this.isOutlined = false,
    this.fontSize = 14,
    this.icon,
  });

  @override
  State<PixelButton> createState() => _PixelButtonState();
}

class _PixelButtonState extends State<PixelButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _glowAnimation = Tween<double>(begin: 0.3, end: 0.8).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) {
        setState(() => _isHovered = true);
        _glowController.repeat(reverse: true);
      },
      onExit: (_) {
        setState(() => _isHovered = false);
        _glowController.stop();
        _glowController.reset();
      },
      child: AnimatedBuilder(
        animation: _glowAnimation,
        builder: (context, child) {
          final glowIntensity = _isHovered ? _glowAnimation.value : 0.2;

          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.isLoading ? null : widget.onPressed,
              borderRadius: BorderRadius.circular(4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                decoration: BoxDecoration(
                  color: widget.isOutlined
                      ? Colors.transparent
                      : CyberpunkColors.darkMatter,
                  border: Border.all(
                    color: widget.neonColor,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [
                    BoxShadow(
                      color: widget.neonColor.withOpacity(glowIntensity),
                      blurRadius: _isHovered ? 16 : 8,
                      spreadRadius: _isHovered ? 2 : 0,
                    ),
                    BoxShadow(
                      color: widget.neonColor.withOpacity(glowIntensity * 0.3),
                      blurRadius: _isHovered ? 32 : 16,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (widget.isLoading)
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(widget.neonColor),
                        ),
                      )
                    else ...[
                      if (widget.icon != null) ...[
                        Icon(
                          widget.icon,
                          color: widget.neonColor,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        widget.text.toUpperCase(),
                        style: TextStyle(
                          color: widget.neonColor,
                          fontSize: widget.fontSize,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                          fontFamily: 'PressStart2P',
                          shadows: NeonGlow.textGlow(widget.neonColor, blur: 4),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Arcade-style card with neon border
class ArcadeCard extends StatefulWidget {
  final Widget child;
  final Color neonColor;
  final String? title;
  final IconData? icon;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;

  const ArcadeCard({
    super.key,
    required this.child,
    this.neonColor = CyberpunkColors.neonGreen,
    this.title,
    this.icon,
    this.onTap,
    this.padding,
    this.borderRadius = 8,
  });

  @override
  State<ArcadeCard> createState() => _ArcadeCardState();
}

class _ArcadeCardState extends State<ArcadeCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _glowAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _glowAnimation = Tween<double>(begin: 0.2, end: 0.6).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) {
        setState(() => _isHovered = true);
        _controller.repeat(reverse: true);
      },
      onExit: (_) {
        setState(() => _isHovered = false);
        _controller.stop();
        _controller.reset();
      },
      child: AnimatedBuilder(
        animation: _glowAnimation,
        builder: (context, child) {
          return GestureDetector(
            onTap: widget.onTap,
            child: Container(
              padding: widget.padding ?? const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: CyberpunkColors.darkMatter,
                border: Border.all(
                  color: widget.neonColor,
                  width: _isHovered ? 2.5 : 2,
                ),
                borderRadius: BorderRadius.circular(widget.borderRadius),
                boxShadow: [
                  BoxShadow(
                    color: widget.neonColor.withOpacity(
                      _isHovered ? _glowAnimation.value : 0.15,
                    ),
                    blurRadius: _isHovered ? 12 : 6,
                  ),
                  BoxShadow(
                    color: CyberpunkColors.voidBlack,
                    blurRadius: 20,
                    spreadRadius: -5,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.title != null || widget.icon != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          if (widget.icon != null) ...[
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: widget.neonColor.withOpacity(0.15),
                                border: Border.all(
                                  color: widget.neonColor.withOpacity(0.5),
                                  width: 1,
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Icon(
                                widget.icon,
                                color: widget.neonColor,
                                size: 16,
                              ),
                            ),
                            const SizedBox(width: 12),
                          ],
                          if (widget.title != null)
                            Expanded(
                              child: Text(
                                widget.title!.toUpperCase(),
                                style: TextStyle(
                                  color: widget.neonColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 2,
                                  fontFamily: 'PressStart2P',
                                  shadows: NeonGlow.textGlow(widget.neonColor, blur: 3),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  widget.child,
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Neon-styled text input field
class NeonTextField extends StatefulWidget {
  final TextEditingController? controller;
  final String? labelText;
  final String? hintText;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final bool obscureText;
  final VoidCallback? onToggleObscure;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final bool enabled;
  final Color neonColor;
  final int maxLines;

  const NeonTextField({
    super.key,
    this.controller,
    this.labelText,
    this.hintText,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.onToggleObscure,
    this.keyboardType,
    this.validator,
    this.onChanged,
    this.enabled = true,
    this.neonColor = CyberpunkColors.neonGreen,
    this.maxLines = 1,
  });

  @override
  State<NeonTextField> createState() => _NeonTextFieldState();
}

class _NeonTextFieldState extends State<NeonTextField> {
  bool _isFocused = false;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() => _isFocused = _focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.labelText != null) ...[
          Text(
            widget.labelText!.toUpperCase(),
            style: TextStyle(
              color: widget.neonColor,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
              fontFamily: 'PressStart2P',
              shadows: NeonGlow.textGlow(widget.neonColor, blur: 2),
            ),
          ),
          const SizedBox(height: 8),
        ],
        TextFormField(
          controller: widget.controller,
          focusNode: _focusNode,
          obscureText: widget.obscureText,
          keyboardType: widget.keyboardType,
          validator: widget.validator,
          onChanged: widget.onChanged,
          enabled: widget.enabled,
          maxLines: widget.maxLines,
          style: TextStyle(
            color: CyberpunkColors.pureWhite,
            fontFamily: 'RobotoMono',
            fontSize: 14,
          ),
          decoration: InputDecoration(
            hintText: widget.hintText,
            hintStyle: TextStyle(
              color: CyberpunkColors.dimGray,
              fontFamily: 'RobotoMono',
            ),
            prefixIcon: widget.prefixIcon != null
                ? Icon(widget.prefixIcon, color: widget.neonColor, size: 20)
                : null,
            suffixIcon: widget.suffixIcon != null
                ? IconButton(
                    icon: Icon(widget.suffixIcon, color: widget.neonColor),
                    onPressed: widget.onToggleObscure,
                  )
                : null,
            filled: true,
            fillColor: CyberpunkColors.circuitBoard,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: BorderSide(color: widget.neonColor, width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: BorderSide(color: widget.neonColor.withOpacity(0.5), width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: BorderSide(color: widget.neonColor, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: const BorderSide(color: CyberpunkColors.hotPink, width: 1),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: const BorderSide(color: CyberpunkColors.hotPink, width: 2),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: BorderSide(color: CyberpunkColors.shadowGray, width: 1),
            ),
          ),
        ),
      ],
    );
  }
}

/// Arcade HUD footer bar
class ArcadeHudFooter extends StatelessWidget {
  final int ecoCredits;
  final int greenLevel;

  const ArcadeHudFooter({
    super.key,
    this.ecoCredits = 0,
    this.greenLevel = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: CyberpunkColors.voidBlack,
        border: Border(
          top: BorderSide(color: CyberpunkColors.neonGreen.withOpacity(0.5), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: CyberpunkColors.neonGreen.withOpacity(0.1),
            blurRadius: 20,
            spreadRadius: -5,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.eco, color: CyberpunkColors.neonGreen, size: 14),
              const SizedBox(width: 6),
              Text(
                'ECO CREDITS: $ecoCredits',
                style: TextStyle(
                  color: CyberpunkColors.neonGreen,
                  fontSize: 8,
                  fontFamily: 'PressStart2P',
                  shadows: NeonGlow.greenTextGlow(),
                ),
              ),
            ],
          ),
          Row(
            children: [
              Icon(Icons.star, color: CyberpunkColors.amber, size: 14),
              const SizedBox(width: 6),
              Text(
                'GREEN LV.$greenLevel',
                style: TextStyle(
                  color: CyberpunkColors.amber,
                  fontSize: 8,
                  fontFamily: 'PressStart2P',
                  shadows: NeonGlow.textGlow(CyberpunkColors.amber),
                ),
              ),
            ],
          ),
          Text(
            'SAVE THE PLANET ©2077',
            style: TextStyle(
              color: CyberpunkColors.dimGray,
              fontSize: 7,
              fontFamily: 'PressStart2P',
            ),
          ),
        ],
      ),
    );
  }
}

/// Pixel-art style recycling icon widget
class PixelRecycleIcon extends StatelessWidget {
  final double size;
  final Color color;
  final bool animated;

  const PixelRecycleIcon({
    super.key,
    this.size = 48,
    this.color = CyberpunkColors.neonGreen,
    this.animated = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        boxShadow: NeonGlow.greenGlow(blur: size / 4),
      ),
      child: Icon(
        Icons.recycling,
        size: size,
        color: color,
      ),
    );
  }
}

/// Cyberpunk-styled app bar
class CyberpunkAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final bool showBack;
  final Color neonColor;
  final Widget? bottom;

  const CyberpunkAppBar({
    super.key,
    required this.title,
    this.actions,
    this.showBack = false,
    this.neonColor = CyberpunkColors.neonGreen,
    this.bottom,
  });

  @override
  Size get preferredSize => Size.fromHeight(bottom != null ? 100 : 60);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: CyberpunkColors.voidBlack,
      elevation: 0,
      leading: showBack
          ? IconButton(
              icon: Icon(Icons.arrow_back, color: neonColor),
              onPressed: () => Navigator.of(context).pop(),
            )
          : null,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.recycling, color: neonColor, size: 24),
          const SizedBox(width: 12),
          Text(
            title.toUpperCase(),
            style: TextStyle(
              color: neonColor,
              fontSize: 12,
              fontFamily: 'PressStart2P',
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
              shadows: NeonGlow.textGlow(neonColor),
            ),
          ),
        ],
      ),
      actions: actions,
      bottom: bottom != null
          ? PreferredSize(
              preferredSize: const Size.fromHeight(40),
              child: bottom!,
            )
          : null,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: neonColor.withOpacity(0.5), width: 1),
          ),
          boxShadow: [
            BoxShadow(
              color: neonColor.withOpacity(0.1),
              blurRadius: 20,
            ),
          ],
        ),
      ),
    );
  }
}

/// Cyberpunk bottom navigation bar
class CyberpunkBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<CyberpunkNavItem> items;

  const CyberpunkBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: CyberpunkColors.voidBlack,
        border: Border(
          top: BorderSide(color: CyberpunkColors.neonGreen.withOpacity(0.3), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: CyberpunkColors.neonGreen.withOpacity(0.1),
            blurRadius: 20,
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(items.length, (index) {
              final item = items[index];
              final isSelected = currentIndex == index;
              final color = isSelected
                  ? CyberpunkColors.neonGreen
                  : CyberpunkColors.dimGray;

              return GestureDetector(
                onTap: () => onTap(index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? CyberpunkColors.neonGreen.withOpacity(0.1)
                        : Colors.transparent,
                    border: isSelected
                        ? Border.all(color: color, width: 1)
                        : null,
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: isSelected
                        ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 8)]
                        : null,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(item.icon, color: color, size: 22),
                      const SizedBox(height: 4),
                      Text(
                        item.label.toUpperCase(),
                        style: TextStyle(
                          color: color,
                          fontSize: 8,
                          fontFamily: 'PressStart2P',
                          shadows: isSelected
                              ? NeonGlow.greenTextGlow()
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class CyberpunkNavItem {
  final IconData icon;
  final String label;

  const CyberpunkNavItem({required this.icon, required this.label});
}

/// Theme data builder
ThemeData buildCyberpunkTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primaryColor: CyberpunkColors.neonGreen,
    scaffoldBackgroundColor: CyberpunkColors.voidBlack,
    colorScheme: const ColorScheme.dark(
      primary: CyberpunkColors.neonGreen,
      secondary: CyberpunkColors.neonCyan,
      tertiary: CyberpunkColors.amber,
      surface: CyberpunkColors.darkMatter,
      onSurface: CyberpunkColors.pureWhite,
      error: CyberpunkColors.hotPink,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: CyberpunkColors.voidBlack,
      foregroundColor: CyberpunkColors.pureWhite,
      elevation: 0,
      centerTitle: true,
    ),
    cardTheme: CardThemeData(
      color: CyberpunkColors.darkMatter,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: CyberpunkColors.neonGreen, width: 1),
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: CyberpunkColors.voidBlack,
      selectedItemColor: CyberpunkColors.neonGreen,
      unselectedItemColor: CyberpunkColors.dimGray,
      type: BottomNavigationBarType.fixed,
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: CyberpunkColors.neonGreen,
        textStyle: const TextStyle(
          fontFamily: 'PressStart2P',
          fontSize: 10,
          letterSpacing: 1,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: CyberpunkColors.neonGreen,
        side: const BorderSide(color: CyberpunkColors.neonGreen, width: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        textStyle: const TextStyle(
          fontFamily: 'PressStart2P',
          fontSize: 10,
          letterSpacing: 1,
        ),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: CyberpunkColors.neonGreen,
        foregroundColor: CyberpunkColors.voidBlack,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        textStyle: const TextStyle(
          fontFamily: 'PressStart2P',
          fontSize: 10,
          letterSpacing: 1,
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: CyberpunkColors.darkMatter,
      contentTextStyle: const TextStyle(
        color: CyberpunkColors.neonGreen,
        fontFamily: 'RobotoMono',
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: const BorderSide(color: CyberpunkColors.neonGreen, width: 1),
      ),
    ),
    dialogTheme: DialogTheme(
      backgroundColor: CyberpunkColors.darkMatter,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: CyberpunkColors.neonGreen, width: 2),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: CyberpunkColors.neonGreen,
      thickness: 0.5,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: CyberpunkColors.neonGreen,
      linearMinHeight: 4,
    ),
    tabBarTheme: const TabBarTheme(
      labelColor: CyberpunkColors.neonGreen,
      unselectedLabelColor: CyberpunkColors.dimGray,
      indicatorColor: CyberpunkColors.neonGreen,
      labelStyle: TextStyle(
        fontFamily: 'PressStart2P',
        fontSize: 8,
      ),
      unselectedLabelStyle: TextStyle(
        fontFamily: 'PressStart2P',
        fontSize: 8,
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: CyberpunkColors.darkMatter,
      foregroundColor: CyberpunkColors.neonGreen,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
    ),
    listTileTheme: const ListTileThemeData(
      textColor: CyberpunkColors.pureWhite,
      iconColor: CyberpunkColors.neonGreen,
    ),
  );
}

/// System UI overlay style
SystemUiOverlayStyle get cyberpunkSystemOverlay => const SystemUiOverlayStyle(
  statusBarColor: CyberpunkColors.voidBlack,
  statusBarIconBrightness: Brightness.light,
  systemNavigationBarColor: CyberpunkColors.voidBlack,
  systemNavigationBarIconBrightness: Brightness.light,
);