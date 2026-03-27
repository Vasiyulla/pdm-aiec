// ============================================================
//  glass_card.dart  —  Reusable glassmorphism card widget
// ============================================================

import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;
  final VoidCallback? onTap;
  final Color? borderColor;
  final Gradient? gradient;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.width,
    this.height,
    this.onTap,
    this.borderColor,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        padding: padding ?? const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: gradient ??
              (isDark ? AppColors.gradientCard : AppColors.gradientCardLight),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: borderColor ??
                (isDark
                    ? AppColors.bg500.withValues(alpha: 0.7)
                    : AppColors.lightBorder),
          ),
          boxShadow: [
            BoxShadow(
              color: (isDark ? Colors.black : Colors.blueGrey)
                  .withValues(alpha: isDark ? 0.2 : 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}

// ── Metric tile ────────────────────────────────────────────────────────────────
class MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final IconData icon;
  final Color color;
  final double? progress; // 0..1 optional progress bar

  const MetricTile({
    super.key,
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      borderColor: color.withValues(alpha: 0.25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top row: icon + unit label
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, size: 15, color: color),
              ),
              Flexible(
                child: Text(unit,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: color.withValues(alpha: 0.7), fontSize: 9, fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Value
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value,
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 22,
                height: 1.1,
              ),
            ),
          ),
          // Label
          Text(label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 11, height: 1.1),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          // Optional progress bar
          if (progress != null) ...[
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: progress!.clamp(0.0, 1.0),
                backgroundColor: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.bg500
                    : AppColors.lightBorder,
                valueColor: AlwaysStoppedAnimation(color),
                minHeight: 2,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Section header ──────────────────────────────────────────────────────────────
class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                style: Theme.of(context).textTheme.titleLarge),
              if (subtitle != null)
                Text(subtitle!,
                  style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

// ── Status chip ─────────────────────────────────────────────────────────────────
class StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool pulsing;

  const StatusChip({
    super.key,
    required this.label,
    required this.color,
    this.pulsing = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6, height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: pulsing
                  ? [BoxShadow(color: color, blurRadius: 4, spreadRadius: 1)]
                  : [],
            ),
          ),
          const SizedBox(width: 5),
          Text(label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: color, fontSize: 10.5, fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
