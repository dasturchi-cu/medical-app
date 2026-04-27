import 'package:flutter/material.dart';

class RankingItem extends StatelessWidget {
  const RankingItem({
    super.key,
    required this.rank,
    required this.name,
    required this.timeLabel,
    required this.isCurrentUser,
    this.prefixLabel,
  });

  final int rank;
  final String name;
  final String timeLabel;
  final bool isCurrentUser;
  final String? prefixLabel;

  Color _rankColor() {
    // Required: 1 Yellow, 2 Blue, 3 Green
    if (rank == 1) return const Color(0xFFFFC107);
    if (rank == 2) return const Color(0xFF1E6BB8);
    if (rank == 3) return const Color(0xFF2E7D32);
    return const Color(0xFF1E6BB8);
  }

  @override
  Widget build(BuildContext context) {
    final bg = isCurrentUser ? const Color(0xFFEAF2FF) : Colors.white;
    final top = rank <= 3;
    final cardColor = top ? _rankColor().withValues(alpha: 0.08) : bg;

    return Card(
      margin: EdgeInsets.zero,
      color: cardColor,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 12,
          vertical: top ? 12 : 10,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 34,
              child: Text(
                '$rank',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: _rankColor(),
                    ),
              ),
            ),
            const SizedBox(width: 6),
            CircleAvatar(
              radius: top ? 20 : 18,
              backgroundColor: _rankColor().withValues(alpha: 0.15),
              child: Icon(Icons.person, color: _rankColor()),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (prefixLabel != null)
                    Text(
                      prefixLabel!,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Colors.black54,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  Text(
                    name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: top ? FontWeight.w900 : FontWeight.w800,
                        ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 110,
              child: Text(
                timeLabel,
                textAlign: TextAlign.right,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: top ? FontWeight.w900 : FontWeight.w800,
                      color: const Color(0xFF1E6BB8),
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

