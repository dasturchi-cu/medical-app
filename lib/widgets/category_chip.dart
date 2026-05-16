import 'package:flutter/material.dart';

import '../core/theme/app_palette.dart';
import '../core/theme/design_system.dart';

class CategoryChip extends StatelessWidget {
  const CategoryChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.appColors;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s8,
            vertical: AppSpacing.s8,
          ),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? p.primary : p.surfaceSecondary,
            borderRadius: BorderRadius.circular(AppRadius.button),
            border: Border.all(
              color: selected ? p.primary : p.border,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: selected ? p.primaryText : p.textPrimary,
                ),
          ),
        ),
      ),
    );
  }
}
