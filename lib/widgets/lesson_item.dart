import 'package:flutter/material.dart';

class LessonItem extends StatelessWidget {
  const LessonItem({
    super.key,
    required this.index,
    required this.title,
    required this.duration,
    required this.locked,
    required this.onTap,
  });

  final int index;
  final String title;
  final String duration;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        leading: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFE9F0FF),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$index',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: const Color(0xFF1E6BB8),
                  fontWeight: FontWeight.w900,
                ),
          ),
        ),
        title: Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        subtitle: Text(
          duration,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.black54,
              ),
        ),
        trailing: Icon(
          locked ? Icons.lock : Icons.play_circle,
          color: locked ? Colors.black38 : const Color(0xFF1E6BB8),
        ),
      ),
    );
  }
}

