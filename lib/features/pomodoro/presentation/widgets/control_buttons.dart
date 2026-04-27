import 'package:flutter/material.dart';

class ControlButtons extends StatelessWidget {
  const ControlButtons({
    super.key,
    required this.isRunning,
    required this.onStart,
    required this.onPause,
    required this.onReset,
    required this.startLabel,
    required this.pauseLabel,
    required this.resetLabel,
  });

  final bool isRunning;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onReset;
  final String startLabel;
  final String pauseLabel;
  final String resetLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: _ActionButton(
            label: startLabel,
            icon: Icons.play_arrow_rounded,
            onTap: onStart,
            enabled: !isRunning,
            isPrimary: true,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ActionButton(
            label: pauseLabel,
            icon: Icons.pause_rounded,
            onTap: onPause,
            enabled: isRunning,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ActionButton(
            label: resetLabel,
            icon: Icons.stop_rounded,
            onTap: onReset,
            enabled: true,
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatefulWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.enabled,
    this.isPrimary = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;
  final bool isPrimary;

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.enabled;
    final baseColor = widget.isPrimary
        ? const Color(0xFF6A76FF)
        : Colors.white.withValues(alpha: 0.15);

    return GestureDetector(
      onTapDown: isEnabled ? (_) => setState(() => _pressed = true) : null,
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: isEnabled ? widget.onTap : null,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        scale: _pressed ? 0.96 : 1,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 180),
          opacity: isEnabled ? 1 : 0.55,
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: baseColor,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.26),
                width: 1.2,
              ),
              boxShadow: widget.isPrimary
                  ? [
                      BoxShadow(
                        color: const Color(0xFF6A76FF).withValues(alpha: 0.45),
                        blurRadius: 24,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(widget.icon, color: Colors.white, size: 20),
                const SizedBox(width: 4),
                Text(
                  widget.label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
