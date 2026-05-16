import 'package:flutter/material.dart';

import '../core/theme/app_palette.dart';

class BaseCard extends StatelessWidget {
  const BaseCard({
    super.key,
    required this.title,
    required this.videoCountText,
    required this.onTap,
  });

  final String title;
  final String videoCountText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.appColors;
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: p.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.account_tree_outlined,
                  color: p.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: p.textPrimary,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.videocam_outlined,
                          size: 16,
                          color: p.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          videoCountText,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: p.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: p.icon),
            ],
          ),
        ),
      ),
    );
  }
}
