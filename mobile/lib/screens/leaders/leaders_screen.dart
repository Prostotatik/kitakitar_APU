import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kitakitar_mobile/services/firestore_service.dart';

class LeadersScreen extends StatelessWidget {
  const LeadersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      // 4 swipeable tabs:
      // Users (points), Users (weight), Centers (points), Centers (weight)
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Leaders'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Users • Points'),
              Tab(text: 'Users • Weight'),
              Tab(text: 'Centers • Points'),
              Tab(text: 'Centers • Weight'),
            ],
          ),
        ),
        body: Column(
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
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primary,
            colorScheme.tertiary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.card_giftcard_rounded,
              color: Colors.white,
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
                  'Rewards from Partners',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Exchange your points for exclusive deals & discounts',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Soon',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 12,
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
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return const Center(child: Text('No data'));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No data'));
        }

        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final rank = index + 1;

            final value = data[metric] ?? 0;
            final formattedValue = isWeight
                ? '${(value as num).toDouble().toStringAsFixed(1)} kg'
                : '${value ?? 0} pts';

            return ListTile(
              leading: CircleAvatar(
                backgroundColor: rank == 1
                    ? Colors.amber
                    : rank == 2
                        ? Colors.grey
                        : rank == 3
                            ? Colors.brown
                            : Colors.green,
                child: Text('$rank'),
              ),
              title: Text(
                (data['name'] ?? (type == 'users' ? 'User' : 'Center'))
                    as String,
              ),
              trailing: Text(
                formattedValue,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

