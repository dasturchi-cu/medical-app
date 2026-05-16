import 'package:flutter/material.dart';

import '../core/theme/app_palette.dart';
import '../core/theme/design_system.dart';

class RankingItem extends StatelessWidget {
  const RankingItem({
    super.key,
    required this.rank,
    required this.name,
    required this.timeLabel,
    required this.isCurrentUser,
    this.prefixLabel,
    this.subtitle,
  });

  final int rank;
  final String name;
  final String timeLabel;
  final bool isCurrentUser;
  final String? prefixLabel;
  final String? subtitle;

  bool get _isTop3 => rank <= 3;

  @override
  Widget build(BuildContext context) {
    final p = context.appColors;
    final rankColor = p.primary;

    Color topBgColor() {
      if (rank == 1) return p.primary.withValues(alpha: 0.12);
      if (rank == 2) return p.primary.withValues(alpha: 0.09);
      return p.primary.withValues(alpha: 0.06);
    }

    final bg = isCurrentUser ? p.surfaceSecondary : p.surface;
    final cardColor = _isTop3 ? topBgColor() : bg;

    return Card(
      margin: EdgeInsets.zero,
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s12,
          vertical: AppSpacing.s12,
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _isTop3
                    ? p.primary.withValues(alpha: 0.18)
                    : p.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Text(
                '$rank',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: rankColor,
                    ),
              ),
            ),
            const SizedBox(width: AppSpacing.s8),
            CircleAvatar(
              radius: _isTop3 ? 20 : 18,
              backgroundColor: rankColor.withValues(alpha: 0.15),
              child: Icon(Icons.person, color: rankColor),
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
                            color: p.textSecondary,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  Text(
                    name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: _isTop3 ? FontWeight.w900 : FontWeight.w800,
                          color: p.textPrimary,
                        ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 120,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    timeLabel,
                    textAlign: TextAlign.right,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: _isTop3 ? FontWeight.w900 : FontWeight.w800,
                          color: p.primary,
                        ),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty)
                    Text(
                      subtitle!,
                      textAlign: TextAlign.right,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: p.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
