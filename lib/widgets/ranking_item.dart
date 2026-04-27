import 'package:flutter/material.dart';

class RankingItem extends StatelessWidget {
  const RankingItem({
    super.key,
    required this.rank,
    required this.name,
    required this.studyMinutes,
    required this.isCurrentUser,
    this.prefixLabel,
  });

  final int rank;
  final String name;
  final int studyMinutes;
  final bool isCurrentUser;
  final String? prefixLabel;

  Color _rankColor() {
    if (rank == 1) return const Color(0xFFFFC107);
    if (rank == 2) return const Color(0xFFB0BEC5);
    if (rank == 3) return const Color(0xFFCD7F32);
    return const Color(0xFF1E6BB8);
  }

  @override
  Widget build(BuildContext context) {
    final bg = isCurrentUser ? const Color(0xFFEAF2FF) : Colors.white;
    final hour = studyMinutes ~/ 60;
    final minute = studyMinutes % 60;
    final timeText = '$hour soat $minute minut';

    return Card(
      margin: EdgeInsets.zero,
      color: bg,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 92,
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
                    '$rank',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: _rankColor(),
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 18,
              backgroundColor: _rankColor().withValues(alpha: 0.15),
              child: Icon(Icons.person, color: _rankColor()),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                name,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
            SizedBox(
              width: 110,
              child: Text(
                timeText,
                textAlign: TextAlign.right,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w900,
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

