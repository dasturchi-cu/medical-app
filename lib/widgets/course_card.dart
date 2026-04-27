import 'package:flutter/material.dart';

import 'course_visual.dart';

class CourseCard extends StatelessWidget {
  const CourseCard({
    super.key,
    required this.visualKind,
    required this.title,
    required this.author,
    required this.progress,
    required this.ratingText,
    required this.buttonText,
    required this.buttonColor,
    required this.onPressed,
    required this.onMessagePressed,
    this.animationDelayMs = 0,
  });

  final String visualKind;
  final String title;
  final String author;
  final double progress;
  final String ratingText;
  final String buttonText;
  final Color buttonColor;
  final VoidCallback onPressed;
  final VoidCallback onMessagePressed;
  final int animationDelayMs;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 420 + animationDelayMs),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value.clamp(0, 1),
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 18),
            child: child,
          ),
        );
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CourseVisual(kind: visualKind),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      author,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.black54),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              value: progress.clamp(0, 1),
                              minHeight: 8,
                              backgroundColor: const Color(0xFFE8ECF3),
                              valueColor: const AlwaysStoppedAnimation(
                                Color(0xFF1E6BB8),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '${(progress * 100).round()}%',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: Colors.black54,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(
                          Icons.star,
                          size: 16,
                          color: Color(0xFFF5B400),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          ratingText,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          onPressed: onMessagePressed,
                          icon: const Icon(Icons.chat_bubble_outline, size: 18),
                          tooltip: 'Izohlar',
                        ),
                        const Spacer(),
                        SizedBox(
                          height: 34,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: buttonColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(999),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                            ),
                            onPressed: onPressed,
                            child: Text(
                              buttonText,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
