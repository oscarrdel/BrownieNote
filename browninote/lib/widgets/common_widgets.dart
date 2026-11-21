import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Card con fondo glassmorphism sutil
class BrownieCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final VoidCallback? onTap;
  final Color? color;
  final double radius;

  const BrownieCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.color,
    this.radius = 16,
  });

  @override
  Widget build(BuildContext context) {
    final colors = BrownieColors.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: color ?? colors.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: colors.divider, width: 1),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withAlpha(20),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(radius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radius),
          child: Padding(
            padding: padding ?? const EdgeInsets.all(16),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Cuadrícula de tarjetas: cuadernos en el inicio, conjuntos y notas dentro
/// de un cuaderno. Todas comparten tamaño.
const brownieTileHeight = 230.0;

SliverGridDelegate brownieTileGrid() =>
    const SliverGridDelegateWithMaxCrossAxisExtent(
      maxCrossAxisExtent: 280,
      mainAxisExtent: brownieTileHeight,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
    );

/// Tarjeta de la cuadrícula: borde redondeado, sombra y efecto al tocar
class BrownieTile extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  final Color? color;
  final Gradient? gradient;
  final Border? border;

  const BrownieTile({
    super.key,
    required this.child,
    required this.onTap,
    this.color,
    this.gradient,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final colors = BrownieColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: gradient == null ? (color ?? colors.surface) : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(20),
        border: border ?? Border.all(color: colors.divider),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withAlpha(20),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: onTap, child: child),
      ),
    );
  }
}

/// Chip pequeño con ícono y texto, para contadores en las tarjetas
class CountChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const CountChip({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Badge de etiqueta de color
class TagBadge extends StatelessWidget {
  final String label;
  final Color? color;

  const TagBadge({super.key, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final colors = BrownieColors.of(context);
    final bg = color ?? colors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg.withAlpha(30),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: bg.withAlpha(80)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: bg,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Indicador de prioridad de tarea
class PriorityDot extends StatelessWidget {
  final String priority; // 'low', 'medium', 'high'

  const PriorityDot({super.key, required this.priority});

  @override
  Widget build(BuildContext context) {
    Color c;
    switch (priority) {
      case 'high':
        c = const Color(0xFFE5524E);
        break;
      case 'low':
        c = const Color(0xFF4EE5B0);
        break;
      default:
        c = const Color(0xFFE5A84E);
    }
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: c,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: c.withAlpha(100), blurRadius: 6, spreadRadius: 1)
        ],
      ),
    );
  }
}

/// Empty state illustration
class EmptyState extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;

  const EmptyState({
    super.key,
    required this.emoji,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final colors = BrownieColors.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: colors.text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(color: colors.subtext, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
