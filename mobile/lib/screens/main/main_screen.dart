import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kitakitar_mobile/providers/scan_filters_provider.dart';
import 'package:kitakitar_mobile/theme/cyberpunk_theme.dart';
import 'package:kitakitar_mobile/screens/scan/scan_screen.dart';
import 'package:kitakitar_mobile/screens/map/map_screen.dart';
import 'package:kitakitar_mobile/screens/leaders/leaders_screen.dart';
import 'package:kitakitar_mobile/screens/profile/profile_screen.dart';

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

  final List<CyberpunkNavItem> _navItems = const [
    CyberpunkNavItem(icon: Icons.camera_alt, label: 'SCAN'),
    CyberpunkNavItem(icon: Icons.map, label: 'MAP'),
    CyberpunkNavItem(icon: Icons.leaderboard, label: 'LEADERS'),
    CyberpunkNavItem(icon: Icons.person, label: 'PROFILE'),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTab ?? 0;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Listen to provider: when user taps "Show on Map" from scan result,
    // shouldSwitchToMap becomes true and we switch to the map tab.
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
      backgroundColor: CyberpunkColors.voidBlack,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: CyberpunkBottomNav(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: _navItems,
      ),
    );
  }
}