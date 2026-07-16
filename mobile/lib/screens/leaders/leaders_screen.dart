import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kitakitar_mobile/services/firestore_service.dart';
import 'package:kitakitar_mobile/theme/app_theme.dart';

class LeadersScreen extends StatelessWidget {
  const LeadersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 6,
      child: Scaffold(
        body: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: const TabBarView(
                children: [
                  _LeaderboardTab(type: 'users', metric: 'points'),
                  _LeaderboardTab(
                      type: 'users',
                      metric: 'carbonFootprint',
                      isCo2: true),
                  _LeaderboardTab(
                      type: 'users', metric: 'totalWeight', isWeight: true),
                  _LeaderboardTab(type: 'centers', metric: 'points'),
                  _LeaderboardTab(
                      type: 'centers',
                      metric: 'carbonFootprint',
                      isCo2: true),
                  _LeaderboardTab(
                      type: 'centers',
                      metric: 'totalWeight',
                      isWeight: true),
                ],
              ),
            ),
            const _RewardsBanner(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Stack(
        children: [
          // Decorative blobs
          Positioned(
            top: -20,
            right: -30,
            child: IgnorePointer(
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withAlpha(10),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 10,
            left: -20,
            child: IgnorePointer(
              child: Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withAlpha(8),
                ),
              ),
            ),
          ),
          Positioned(
            top: 50,
            left: 40,
            child: IgnorePointer(
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withAlpha(25),
                ),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Row(
                    children: [
                      const Icon(Icons.emoji_events_rounded,
                          color: Color(0xFFFFD54F), size: 28),
                      const SizedBox(width: 10),
                      const Text(
                        'Leaderboard',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(25),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.local_fire_department_rounded,
                                color: Color(0xFFFF8A65), size: 16),
                            SizedBox(width: 4),
                            Text(
                              'Live',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  labelStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white54,
                  indicatorSize: TabBarIndicatorSize.label,
                  indicatorColor: Colors.white,
                  indicatorWeight: 3,
                  dividerColor: Colors.transparent,
                  tabs: const [
                    Tab(text: 'Users \u2022 Kitar Pts'),
                    Tab(text: 'Users \u2022 CO\u2082'),
                    Tab(text: 'Users \u2022 Weight'),
                    Tab(text: 'Centers \u2022 Kitar Pts'),
                    Tab(text: 'Centers \u2022 CO\u2082'),
                    Tab(text: 'Centers \u2022 Weight'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

String _formatValue(dynamic value,
    {bool isWeight = false, bool isCo2 = false}) {
  if (isWeight) {
    return '${(value as num).toDouble().toStringAsFixed(1)} kg';
  } else if (isCo2) {
    return '${(value as num).toDouble().toStringAsFixed(2)} kg CO\u2082';
  }
  return '$value pts';
}

const _trophyColors = [
  Color(0xFFFFD700),
  Color(0xFFB0BEC5),
  Color(0xFFE6A147),
];

const _cardGradients = [
  [Color(0xFF00C853), Color(0xFF69F0AE)],
  [Color(0xFF78909C), Color(0xFFB0BEC5)],
  [Color(0xFFE6A147), Color(0xFFFFC97B)],
];

// ---------------------------------------------------------------------------
// Tab content
// ---------------------------------------------------------------------------

class _LeaderboardTab extends StatelessWidget {
  final String type;
  final String metric;
  final bool isWeight;
  final bool isCo2;

  const _LeaderboardTab({
    required this.type,
    required this.metric,
    this.isWeight = false,
    this.isCo2 = false,
  });

  @override
  Widget build(BuildContext context) {
    final firestoreService = FirestoreService();

    return StreamBuilder<List<QueryDocumentSnapshot>>(
      stream: firestoreService.getLeaderboard(type, metric: metric),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError ||
            !snapshot.hasData ||
            snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.emoji_events_outlined,
                      size: 40, color: Colors.grey.shade300),
                ),
                const SizedBox(height: 16),
                Text(
                  'No rankings yet',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade500,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Start recycling to appear here!',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade400,
                  ),
                ),
              ],
            ),
          );
        }

        final docs = snapshot.data!;
        final hasPodium = docs.length >= 3;
        final listStart = hasPodium ? 3 : 0;

        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 8),
          itemCount: (hasPodium ? 1 : 0) + (docs.length - listStart),
          itemBuilder: (context, index) {
            if (hasPodium && index == 0) {
              return _Podium(
                docs: docs,
                type: type,
                metric: metric,
                isWeight: isWeight,
                isCo2: isCo2,
              );
            }

            final docIndex = listStart + (hasPodium ? index - 1 : index);
            final data = docs[docIndex].data() as Map<String, dynamic>;
            final rank = docIndex + 1;
            final name = (data['name'] ??
                (type == 'users' ? 'User' : 'Center')) as String;
            final value = data[metric] ?? 0;
            final avatarUrl = data['avatarUrl'] as String?;

            return _ListRow(
              rank: rank,
              name: name,
              formattedValue:
                  _formatValue(value, isWeight: isWeight, isCo2: isCo2),
              avatarUrl: avatarUrl,
              isUser: type == 'users',
            );
          },
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Podium (top 3)
// ---------------------------------------------------------------------------

class _Podium extends StatelessWidget {
  final List<QueryDocumentSnapshot> docs;
  final String type;
  final String metric;
  final bool isWeight;
  final bool isCo2;

  const _Podium({
    required this.docs,
    required this.type,
    required this.metric,
    this.isWeight = false,
    this.isCo2 = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      padding: const EdgeInsets.fromLTRB(8, 16, 8, 20),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(child: _buildSlot(context, 1)),
          const SizedBox(width: 6),
          Expanded(child: _buildSlot(context, 0)),
          const SizedBox(width: 6),
          Expanded(child: _buildSlot(context, 2)),
        ],
      ),
    );
  }

  Widget _buildSlot(BuildContext context, int index) {
    final data = docs[index].data() as Map<String, dynamic>;
    final name =
        (data['name'] ?? (type == 'users' ? 'User' : 'Center')) as String;
    final value = data[metric] ?? 0;
    final avatarUrl = data['avatarUrl'] as String?;
    final formatted =
        _formatValue(value, isWeight: isWeight, isCo2: isCo2);

    final trophyColor = _trophyColors[index];
    final gradient = _cardGradients[index];

    const cardHeights = [140.0, 115.0, 100.0];
    final cardHeight = cardHeights[index];
    const avatarRadius = 26.0;
    const trophySize = 38.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Trophy with glow
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: trophyColor.withAlpha(60),
                blurRadius: 12,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Icon(Icons.emoji_events_rounded,
              color: trophyColor, size: trophySize),
        ),
        const SizedBox(height: 2),

        // Rank badge
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: trophyColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: trophyColor.withAlpha(40),
                blurRadius: 4,
              ),
            ],
          ),
          child: Center(
            child: Text(
              '${index + 1}',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),

        // Card + avatar
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            Container(
              width: double.infinity,
              height: cardHeight,
              margin: const EdgeInsets.only(top: avatarRadius),
              padding: EdgeInsets.only(
                  top: avatarRadius + 8, left: 6, right: 6, bottom: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: gradient,
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: gradient[0].withAlpha(60),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(35),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      formatted,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(25),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: CircleAvatar(
                radius: avatarRadius,
                backgroundColor: gradient[1].withAlpha(80),
                backgroundImage:
                    avatarUrl != null ? NetworkImage(avatarUrl) : null,
                child: avatarUrl == null
                    ? Icon(
                        type == 'users' ? Icons.person : Icons.store,
                        color: Colors.white,
                        size: 24,
                      )
                    : null,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// List row (rank 4+)
// ---------------------------------------------------------------------------

class _ListRow extends StatelessWidget {
  final int rank;
  final String name;
  final String formattedValue;
  final String? avatarUrl;
  final bool isUser;

  const _ListRow({
    required this.rank,
    required this.name,
    required this.formattedValue,
    required this.avatarUrl,
    required this.isUser,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade100,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: _rankColor(rank),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$rank',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: rank <= 10
                      ? Colors.white
                      : Colors.grey.shade600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.primaryLight.withAlpha(30),
            backgroundImage:
                avatarUrl != null ? NetworkImage(avatarUrl!) : null,
            child: avatarUrl == null
                ? Icon(
                    isUser ? Icons.person : Icons.store,
                    size: 18,
                    color: AppColors.primary,
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primaryLight.withAlpha(18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              formattedValue,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  static Color _rankColor(int rank) {
    if (rank <= 5) return const Color(0xFF43A047);
    if (rank <= 10) return const Color(0xFFA5D6A7);
    return Colors.grey.shade100;
  }
}

// ---------------------------------------------------------------------------
// Rewards banner (bottom)
// ---------------------------------------------------------------------------

class _RewardsBanner extends StatelessWidget {
  const _RewardsBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withAlpha(60),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -10,
            top: -10,
            child: Icon(Icons.card_giftcard_rounded,
                size: 60, color: Colors.white.withAlpha(15)),
          ),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(40),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.card_giftcard_rounded,
                    color: Colors.white, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Rewards from Partners',
                      style:
                          Theme.of(context).textTheme.titleSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Exchange your Kitar Points for exclusive deals & discounts',
                      style:
                          Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.white.withAlpha(215),
                              ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(40),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Soon',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
