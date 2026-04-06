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
        appBar: AppBar(
          title: Text('LEADERS', style: CyberpunkText.pixelHeading(fontSize: 12)),
          backgroundColor: CyberpunkColors.backgroundDeep,
          elevation: 0,
          bottom: TabBar(
            isScrollable: true,
            indicatorColor: CyberpunkColors.neonGreen,
            indicatorWeight: 2,
            labelColor: CyberpunkColors.neonGreen,
            unselectedLabelColor: CyberpunkColors.textSecondary,
            labelStyle: CyberpunkText.pixelLabel(fontSize: 8),
            unselectedLabelStyle: CyberpunkText.pixelLabel(fontSize: 8, color: CyberpunkColors.textSecondary),
            tabs: const [
              Tab(text: 'USERS • PTS'),
              Tab(text: 'USERS • KG'),
              Tab(text: 'CENTERS • PTS'),
              Tab(text: 'CENTERS • KG'),
            ],
          ),
        ),
        body: CircuitGridBackground(
          child: Column(
            children: [
              const Expanded(
                child: TabBarView(
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
              const _CyberpunkRewardsBanner(),
            ],
          ),
        ),
      ),
    );
  }
}

class _CyberpunkRewardsBanner extends StatelessWidget {
  const _CyberpunkRewardsBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: CyberpunkColors.backgroundJungle,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: CyberpunkColors.electricLime, width: 2),
        boxShadow: CyberpunkGlow.limeGlow(intensity: 0.3),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: CyberpunkColors.electricLime.withOpacity(0.1),
              borderRadius: BorderRadius.circular(2),
              border: Border.all(color: CyberpunkColors.electricLime, width: 1),
            ),
            child: const Icon(
              Icons.card_giftcard_rounded,
              color: CyberpunkColors.electricLime,
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
                  style: CyberpunkText.pixelLabel(
                    fontSize: 8,
                    color: CyberpunkColors.electricLime,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Exchange points for exclusive deals',
                  style: CyberpunkText.bodyText(
                    fontSize: 12,
                    color: CyberpunkColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: CyberpunkColors.toxicGlow.withOpacity(0.2),
              borderRadius: BorderRadius.circular(2),
              border: Border.all(color: CyberpunkColors.toxicGlow, width: 1),
            ),
            child: Text(
              'COMING SOON',
              style: CyberpunkText.pixelLabel(
                fontSize: 7,
                color: CyberpunkColors.toxicGlow,
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

  Color _getRankColor(int rank) {
    switch (rank) {
      case 1:
        return CyberpunkColors.electricLime;
      case 2:
        return CyberpunkColors.neonGreen;
      case 3:
        return CyberpunkColors.toxicGlow;
      default:
        return CyberpunkColors.amberMoss;
    }
  }

  @override
  Widget build(BuildContext context) {
    final firestoreService = FirestoreService();

    return StreamBuilder<QuerySnapshot>(
      stream: firestoreService.getLeaderboard(type, metric: metric),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: CyberpunkColors.neonGreen),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'ERROR LOADING DATA',
              style: CyberpunkText.pixelLabel(fontSize: 10),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Text(
              'NO DATA AVAILABLE',
              style: CyberpunkText.pixelLabel(fontSize: 10),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final rank = index + 1;

            final value = data[metric] ?? 0;
            final formattedValue = isWeight
                ? '${(value as num).toDouble().toStringAsFixed(1)} KG'
                : '${value ?? 0} PTS';

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: CyberpunkColors.backgroundMoss,
                borderRadius: BorderRadius.circular(2),
                border: Border.all(
                  color: rank <= 3 ? _getRankColor(rank) : CyberpunkColors.amberMoss,
                  width: rank <= 3 ? 2 : 1,
                ),
                boxShadow: rank <= 3
                    ? [
                        BoxShadow(
                          color: _getRankColor(rank).withOpacity(0.2),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
              child: ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _getRankColor(rank).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(2),
                    border: Border.all(color: _getRankColor(rank), width: 1),
                  ),
                  child: Center(
                    child: Text(
                      '$rank',
                      style: CyberpunkText.pixelHeading(
                        fontSize: 12,
                        color: _getRankColor(rank),
                        glow: rank <= 3,
                      ),
                    ),
                  ),
                ),
                title: Text(
                  (data['name'] ?? (type == 'users' ? 'User' : 'Center'))
                      as String,
                  style: CyberpunkText.bodyText(),
                ),
                trailing: Text(
                  formattedValue,
                  style: CyberpunkText.pixelHeading(
                    fontSize: 10,
                    color: CyberpunkColors.neonGreen,
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