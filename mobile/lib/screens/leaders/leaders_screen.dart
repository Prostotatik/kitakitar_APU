import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kitakitar_mobile/services/firestore_service.dart';
import 'package:kitakitar_mobile/theme/cyberpunk_theme.dart';

class LeadersScreen extends StatelessWidget {
  const LeadersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: CyberpunkColors.voidBlack,
        appBar: AppBar(
          backgroundColor: CyberpunkColors.voidBlack,
          elevation: 0,
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.leaderboard, color: CyberpunkColors.amber, size: 24),
              const SizedBox(width: 12),
              Text(
                'LEADERBOARD',
                style: TextStyle(
                  color: CyberpunkColors.amber,
                  fontSize: 12,
                  fontFamily: 'PressStart2P',
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                  shadows: NeonGlow.amberTextGlow(),
                ),
              ),
            ],
          ),
          flexibleSpace: Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: CyberpunkColors.amber.withOpacity(0.3), width: 1),
              ),
              boxShadow: [
                BoxShadow(
                  color: CyberpunkColors.amber.withOpacity(0.1),
                  blurRadius: 20,
                ),
              ],
            ),
          ),
          bottom: const TabBar(
            isScrollable: true,
            indicatorColor: CyberpunkColors.amber,
            indicatorWeight: 2,
            labelColor: CyberpunkColors.amber,
            unselectedLabelColor: CyberpunkColors.dimGray,
            labelStyle: TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 8,
            ),
            tabs: [
              Tab(text: 'USERS • POINTS'),
              Tab(text: 'USERS • WEIGHT'),
              Tab(text: 'CENTERS • POINTS'),
              Tab(text: 'CENTERS • WEIGHT'),
            ],
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: CyberpunkColors.voidBlack,
                ),
                child: const TabBarView(
                  children: [
                    _LeaderboardList(
                      type: 'users',
                      metric: 'points',
                    ),
                    _LeaderboardList(
                      type: 'users',
                      metric: 'totalWeight',
                      isWeight: true,
                    ),
                    _LeaderboardList(
                      type: 'centers',
                      metric: 'points',
                    ),
                    _LeaderboardList(
                      type: 'centers',
                      metric: 'totalWeight',
                      isWeight: true,
                    ),
                  ],
                ),
              ),
            ),
            const _RewardsBanner(),
          ],
        ),
      ),
    );
  }
}

class _RewardsBanner extends StatelessWidget {
  const _RewardsBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: CyberpunkColors.darkMatter,
        border: Border.all(color: CyberpunkColors.neonCyan, width: 2),
        borderRadius: BorderRadius.circular(8),
        boxShadow: NeonGlow.cyanGlow(blur: 16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: CyberpunkColors.neonCyan.withOpacity(0.15),
              border: Border.all(color: CyberpunkColors.neonCyan.withOpacity(0.5), width: 1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.card_giftcard_rounded,
              color: CyberpunkColors.neonCyan,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'REWARDS FROM PARTNERS',
                  style: TextStyle(
                    color: CyberpunkColors.neonCyan,
                    fontSize: 10,
                    fontFamily: 'PressStart2P',
                    fontWeight: FontWeight.bold,
                    shadows: NeonGlow.cyanTextGlow(),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Exchange credits for exclusive deals',
                  style: TextStyle(
                    color: CyberpunkColors.mistGray,
                    fontSize: 10,
                    fontFamily: 'RobotoMono',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: CyberpunkColors.neonCyan.withOpacity(0.2),
              border: Border.all(color: CyberpunkColors.neonCyan.withOpacity(0.5), width: 1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'SOON',
              style: TextStyle(
                color: CyberpunkColors.neonCyan,
                fontWeight: FontWeight.w600,
                fontSize: 10,
                fontFamily: 'PressStart2P',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaderboardList extends StatelessWidget {
  final String type;
  final String metric;
  final bool isWeight;

  const _LeaderboardList({
    required this.type,
    required this.metric,
    this.isWeight = false,
  });

  @override
  Widget build(BuildContext context) {
    final firestoreService = FirestoreService();

    return StreamBuilder<QuerySnapshot>(
      stream: firestoreService.getLeaderboard(type, metric: metric),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(CyberpunkColors.amber),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'LOADING DATA...',
                  style: TextStyle(
                    color: CyberpunkColors.amber,
                    fontSize: 10,
                    fontFamily: 'PressStart2P',
                  ),
                ),
              ],
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'ERROR LOADING DATA',
              style: TextStyle(
                color: CyberpunkColors.hotPink,
                fontSize: 12,
                fontFamily: 'PressStart2P',
              ),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.emoji_events_outlined,
                  size: 64,
                  color: CyberpunkColors.dimGray,
                ),
                const SizedBox(height: 16),
                Text(
                  'NO DATA AVAILABLE',
                  style: TextStyle(
                    color: CyberpunkColors.dimGray,
                    fontSize: 12,
                    fontFamily: 'PressStart2P',
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final rank = index + 1;

            final value = data[metric] ?? 0;
            final formattedValue = isWeight
                ? '${(value as num).toDouble().toStringAsFixed(1)} KG'
                : '${value ?? 0} PTS';

            // Determine rank color
            Color rankColor;
            IconData rankIcon;
            if (rank == 1) {
              rankColor = CyberpunkColors.amber;
              rankIcon = Icons.emoji_events;
            } else if (rank == 2) {
              rankColor = CyberpunkColors.mistGray;
              rankIcon = Icons.military_tech;
            } else if (rank == 3) {
              rankColor = CyberpunkColors.sunsetOrange;
              rankIcon = Icons.military_tech;
            } else {
              rankColor = CyberpunkColors.neonGreen;
              rankIcon = Icons.star_outline;
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: CyberpunkColors.darkMatter,
                border: Border.all(
                  color: rank <= 3 ? rankColor.withOpacity(0.5) : CyberpunkColors.neonGreen.withOpacity(0.3),
                  width: rank <= 3 ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(8),
                boxShadow: rank <= 3
                    ? [BoxShadow(color: rankColor.withOpacity(0.2), blurRadius: 12)]
                    : null,
              ),
              child: ListTile(
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: rankColor.withOpacity(0.15),
                    border: Border.all(color: rankColor, width: 2),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: rank <= 3 ? [BoxShadow(color: rankColor.withOpacity(0.3), blurRadius: 8)] : null,
                  ),
                  child: Center(
                    child: rank <= 3
                        ? Icon(rankIcon, color: rankColor, size: 20)
                        : Text(
                            '$rank',
                            style: TextStyle(
                              color: rankColor,
                              fontSize: 12,
                              fontFamily: 'PressStart2P',
                            ),
                          ),
                  ),
                ),
                title: Text(
                  (data['name'] ?? (type == 'users' ? 'USER' : 'CENTER')) as String,
                  style: TextStyle(
                    color: CyberpunkColors.pureWhite,
                    fontSize: 12,
                    fontFamily: 'PressStart2P',
                  ),
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: rankColor.withOpacity(0.1),
                    border: Border.all(color: rankColor.withOpacity(0.5), width: 1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    formattedValue,
                    style: TextStyle(
                      color: rankColor,
                      fontSize: 10,
                      fontFamily: 'PressStart2P',
                      fontWeight: FontWeight.w700,
                      shadows: NeonGlow.textGlow(rankColor, blur: 4),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}