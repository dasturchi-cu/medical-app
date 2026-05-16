import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/design_system.dart';

class TimerCard extends StatelessWidget {
  const TimerCard({
    super.key,
    required this.remainingSeconds,
    required this.totalSeconds,
    required this.label,
  });

  final int remainingSeconds;
  final int totalSeconds;
  final String label;

  @override
  Widget build(BuildContext context) {
    final p = context.appColors;
    final progress = totalSeconds == 0
        ? 0.0
        : (totalSeconds - remainingSeconds) / totalSeconds;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s16),
        child: Column(
          children: [
            SizedBox(
              width: 190,
              height: 190,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 170,
                    height: 170,
                    child: CircularProgressIndicator(
                      value: progress.clamp(0, 1),
                      strokeWidth: AppSpacing.s8,
                      backgroundColor: p.surfaceSecondary,
                      valueColor: AlwaysStoppedAnimation(p.primary),
                      strokeCap: StrokeCap.round,
                    ),
                  ),
                  Container(
                    width: 138,
                    height: 138,
                    decoration: BoxDecoration(
                      color: p.surface,
                      shape: BoxShape.circle,
                      border: Border.all(color: p.border),
                    ),
                    child: Center(
                      child: Text(
                        _formatDuration(remainingSeconds),
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: p.textPrimary,
                            ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.s8),
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: p.textSecondary,
                  ),
            ),
            const SizedBox(height: AppSpacing.s4),
            Text(
              '${(progress * 100).round()}%',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: p.primary,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatDuration(int seconds) {
  final m = (seconds ~/ 60).toString().padLeft(2, '0');
  final s = (seconds % 60).toString().padLeft(2, '0');
  return '$m:$s';
}
