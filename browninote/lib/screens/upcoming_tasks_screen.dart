import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/task_urgency.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../widgets/task_tile.dart';

/// Todas las tareas pendientes de todos los cuadernos, ordenadas por urgencia
class UpcomingTasksScreen extends StatefulWidget {
  const UpcomingTasksScreen({super.key});

  @override
  State<UpcomingTasksScreen> createState() => _UpcomingTasksScreenState();
}

class _UpcomingTasksScreenState extends State<UpcomingTasksScreen> {
  /// null = todos los cuadernos
  String? _notebookFilter;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final colors = BrownieColors.of(context);

    final all = UrgencyEngine.rank(provider.tasks)
        .where((u) => provider.notebookById(u.task.notebookId) != null)
        .toList();
    final ranked = _notebookFilter == null
        ? all
        : all.where((u) => u.task.notebookId == _notebookFilter).toList();

    final byLevel = <UrgencyLevel, List<TaskUrgency>>{};
    for (final u in ranked) {
      byLevel.putIfAbsent(u.level, () => []).add(u);
    }
    final critical = byLevel[UrgencyLevel.critical]?.length ?? 0;
    final overdue = ranked.where((u) => u.isOverdue).length;

    return Scaffold(
      backgroundColor: colors.bg,
      body: CustomScrollView(
        slivers: [
          // ─── Header ────────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              padding: EdgeInsets.fromLTRB(
                  8, MediaQuery.paddingOf(context).top + 16, 20, 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFE5524E).withAlpha(220),
                    const Color(0xFFE5A84E).withAlpha(200),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const BackButton(color: Colors.white),
                      const SizedBox(width: 4),
                      const Expanded(
                        child: Text(
                          '⏰ Tareas próximas',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: '¿Cómo se ordenan?',
                        icon: const Icon(Icons.help_outline,
                            color: Colors.white),
                        onPressed: () => _showHowItWorks(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _HeaderStat(
                            label: '${ranked.length} pendientes'),
                        if (critical > 0)
                          _HeaderStat(label: '🔥 $critical críticas'),
                        if (overdue > 0)
                          _HeaderStat(label: '⚠️ $overdue vencidas'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ─── Filtro por cuaderno ───────────────────────────────────────────
          if (provider.notebooks.length > 1)
            SliverToBoxAdapter(
              child: SizedBox(
                height: 56,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  children: [
                    _FilterChip(
                      label: 'Todos',
                      selected: _notebookFilter == null,
                      color: colors.primary,
                      onTap: () => setState(() => _notebookFilter = null),
                    ),
                    for (final nb in provider.notebooks)
                      _FilterChip(
                        label: '${nb.emoji} ${nb.name}',
                        selected: _notebookFilter == nb.id,
                        color: nb.color,
                        onTap: () => setState(() => _notebookFilter = nb.id),
                      ),
                  ],
                ),
              ),
            ),

          // ─── Lista ─────────────────────────────────────────────────────────
          if (ranked.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                emoji: '🎉',
                title: '¡Todo al día!',
                subtitle: 'No tienes tareas pendientes',
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              sliver: SliverList.list(
                children: [
                  for (final level in UrgencyLevel.values)
                    if (byLevel[level] != null) ...[
                      _LevelHeader(level: level, count: byLevel[level]!.length),
                      for (final u in byLevel[level]!)
                        TaskTile(
                          key: ValueKey(u.task.id),
                          task: u.task,
                          notebook: provider.notebookById(u.task.notebookId)!,
                          showNotebook: true,
                        ),
                    ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _showHowItWorks(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Cómo se ordenan?'),
        content: const SingleChildScrollView(
          child: Text(
            'BrownieNote calcula la urgencia real de cada tarea con la fecha '
            'de entrega y la prioridad que le pusiste:\n\n'
            '🔥 Crítica: tareas vencidas o que se entregan hoy o mañana. Van '
            'primero sin importar su prioridad. Una tarea de prioridad baja '
            'para mañana va antes que una alta para la próxima semana.\n\n'
            '⚡ Alta / 📌 Media / 🌱 Baja: para lo demás, la prioridad adelanta '
            'la fecha. Una tarea de prioridad alta se trata como si se '
            'entregara 3.5 días antes, y una media 1.5 días antes.\n\n'
            '🗂️ Sin fecha: al final, ordenadas por prioridad.\n\n'
            'Si le pones hora de entrega a una tarea, el orden es todavía '
            'más preciso.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }
}

class _HeaderStat extends StatelessWidget {
  final String label;
  const _HeaderStat({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(45),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = BrownieColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: color.withAlpha(40),
        side: BorderSide(color: selected ? color : colors.divider),
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: selected ? color : colors.subtext,
        ),
        showCheckmark: false,
      ),
    );
  }
}

class _LevelHeader extends StatelessWidget {
  final UrgencyLevel level;
  final int count;
  const _LevelHeader({required this.level, required this.count});

  @override
  Widget build(BuildContext context) {
    final colors = BrownieColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 10),
      child: Row(
        children: [
          Text(level.emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Text(
            '${level.label} ($count)',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: level.color,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              level.description,
              style: TextStyle(fontSize: 12, color: colors.subtext),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
