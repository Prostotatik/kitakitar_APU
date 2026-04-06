import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kitakitar_mobile/providers/scan_filters_provider.dart';
import 'package:kitakitar_mobile/screens/scan/scan_screen.dart';
import 'package:kitakitar_mobile/screens/map/map_screen.dart';
import 'package:kitakitar_mobile/screens/leaders/leaders_screen.dart';
import 'package:kitakitar_mobile/screens/profile/profile_screen.dart';
import 'package:kitakitar_mobile/theme/cyberpunk_theme.dart';

class MainScreen extends StatefulWidget {
  final int? initialTab;

  const MainScreen({super.key, this.initialTab});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late int _currentIndex;

  final List<Widget> _screens = [
    const ScanScreen(),
    const MapScreen(),
    const LeadersScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTab ?? 0;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = Provider.of<ScanFiltersProvider>(context);
    if (provider.shouldSwitchToMap) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _currentIndex = 1);
        Provider.of<ScanFiltersProvider>(context, listen: false)
            .clearSwitchToMapFlag();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: CyberpunkColors.backgroundDeep,
          border: const Border(
            top: BorderSide(color: CyberpunkColors.neonGreen, width: 1),
          ),
          boxShadow: CyberpunkGlow.greenGlow(intensity: 0.2),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.camera_alt, 'SCAN'),
                _buildNavItem(1, Icons.map, 'MAP'),
                _buildNavItem(2, Icons.leaderboard, 'LEADERS'),
                _buildNavItem(3, Icons.person, 'PROFILE'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? CyberpunkColors.neonGreen.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(2),
          border: Border.all(
            color: isSelected ? CyberpunkColors.neonGreen : Colors.transparent,
            width: 1,
          ),
          boxShadow: isSelected ? CyberpunkGlow.greenGlow(intensity: 0.3) : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected
                  ? CyberpunkColors.neonGreen
                  : CyberpunkColors.textSecondary,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: CyberpunkText.pixelLabel(
                fontSize: 6,
                color: isSelected
                    ? CyberpunkColors.neonGreen
                    : CyberpunkColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}