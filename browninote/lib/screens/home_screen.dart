import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/app_provider.dart';
import '../services/task_urgency.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../widgets/notebook_dialogs.dart';
import 'calendar_screen.dart';
import 'notebook_screen.dart';
import 'upcoming_tasks_screen.dart';

/// Página de inicio: tareas próximas y cuadernos en una cuadrícula
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final colors = BrownieColors.of(context);
    // En teléfono la cuadrícula queda en 2 columnas; ahí las tareas próximas
    // ocupan todo el ancho para que se lean mejor.
    final narrow = MediaQuery.sizeOf(context).width < 600;

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _Header(provider: provider)),
            if (narrow)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                sliver: SliverToBoxAdapter(
                  child: SizedBox(
                    height: brownieTileHeight,
                    child: _UpcomingTile(provider: provider),
                  ),
                ),
              ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              sliver: SliverGrid(
                gridDelegate: brownieTileGrid(),
                delegate: SliverChildListDelegate([
                  if (!narrow) _UpcomingTile(provider: provider),
                  for (final nb in provider.notebooks)
                    _NotebookTile(
                      notebook: nb,
                      noteCount: provider.notesForNotebook(nb.id).length,
                      pendingCount: provider
                          .tasksForNotebook(nb.id)
                          .where((t) => !t.isCompleted)
                          .length,
                    ),
                  const _NewNotebookTile(),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Header ──────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final AppProvider provider;
  const _Header({required this.provider});

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Buenos días';
    if (h < 19) return 'Buenas tardes';
    return 'Buenas noches';
  }

  @override
  Widget build(BuildContext context) {
    final colors = BrownieColors.of(context);
    final wide = MediaQuery.sizeOf(context).width > 560;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [colors.primary, colors.secondary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Text('🍪', style: TextStyle(fontSize: 24)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'BrownieNote',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: colors.text,
                  ),
                ),
                Text(
                  '$_greeting · ${provider.notebooks.length} '
                  '${provider.notebooks.length == 1 ? 'cuaderno' : 'cuadernos'}',
                  style: TextStyle(fontSize: 13, color: colors.subtext),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Calendario',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CalendarScreen()),
            ),
            icon: Icon(Icons.calendar_month_outlined, color: colors.text),
          ),
          IconButton(
            tooltip: 'Ajustes',
            onPressed: () => _openSettings(context, provider),
            icon: Icon(Icons.settings_outlined, color: colors.text),
          ),
          const SizedBox(width: 4),
          wide
              ? FilledButton.icon(
                  onPressed: () => showNotebookForm(context),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text(
                    'Nuevo cuaderno',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                )
              : IconButton.filled(
                  tooltip: 'Nuevo cuaderno',
                  onPressed: () => showNotebookForm(context),
                  icon: const Icon(Icons.add),
                ),
        ],
      ),
    );
  }
}

// ─── Tiles ───────────────────────────────────────────────────────────────────

class _UpcomingTile extends StatelessWidget {
  final AppProvider provider;
  const _UpcomingTile({required this.provider});

  @override
  Widget build(BuildContext context) {
    final ranked = UrgencyEngine.rank(provider.tasks)
        .where((u) => provider.notebookById(u.task.notebookId) != null)
        .toList();
    final critical = ranked
        .where((u) => u.level == UrgencyLevel.critical)
        .length;

    return BrownieTile(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const UpcomingTasksScreen()),
      ),
      gradient: const LinearGradient(
        colors: [Color(0xFF2A2350), Color(0xFF4A3B8F)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      border: Border.all(color: Colors.transparent),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('⏰', style: TextStyle(fontSize: 22)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Tareas próximas',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (critical > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: UrgencyLevel.critical.color,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '🔥 $critical',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              ranked.isEmpty
                  ? 'Nada pendiente'
                  : '${ranked.length} pendientes, por urgencia',
              style: TextStyle(
                color: Colors.white.withAlpha(180),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ranked.isEmpty
                  ? const Center(
                      child: Text(
                        '🎉 ¡Todo al día!',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  : Column(
                      children: [
                        for (final u in ranked.take(3))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: u.level.color,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    u.task.title,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  u.dueLabel,
                                  style: TextStyle(
                                    color: u.level == UrgencyLevel.critical
                                        ? const Color(0xFFFF8A80)
                                        : Colors.white.withAlpha(170),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Ver todas',
                  style: TextStyle(
                    color: Colors.white.withAlpha(220),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Icon(
                  Icons.arrow_forward,
                  size: 14,
                  color: Colors.white.withAlpha(220),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NotebookTile extends StatelessWidget {
  final Notebook notebook;
  final int noteCount;
  final int pendingCount;

  const _NotebookTile({
    required this.notebook,
    required this.noteCount,
    required this.pendingCount,
  });

  @override
  Widget build(BuildContext context) {
    final colors = BrownieColors.of(context);
    return BrownieTile(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => NotebookScreen(notebookId: notebook.id),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Portada del cuaderno
          Container(
            height: 96,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [notebook.color, notebook.color.withAlpha(150)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Stack(
              children: [
                // Lomo
                Positioned(
                  left: 14,
                  top: 0,
                  bottom: 0,
                  child: Container(width: 3, color: Colors.white.withAlpha(60)),
                ),
                Center(
                  child: Text(
                    notebook.emoji,
                    style: const TextStyle(fontSize: 40),
                  ),
                ),
                Positioned(
                  right: 0,
                  top: 0,
                  child: PopupMenuButton<String>(
                    icon: const Icon(Icons.more_horiz, color: Colors.white),
                    onSelected: (v) {
                      if (v == 'edit') {
                        showNotebookForm(context, notebook: notebook);
                      }
                      if (v == 'delete') {
                        confirmDeleteNotebook(context, notebook);
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Editar')),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text(
                          'Eliminar',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notebook.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: colors.text,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (notebook.subject.isNotEmpty)
                    Text(
                      notebook.subject,
                      style: TextStyle(fontSize: 12, color: colors.subtext),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const Spacer(),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      CountChip(
                        icon: Icons.note_outlined,
                        label:
                            '$noteCount ${noteCount == 1 ? 'nota' : 'notas'}',
                        color: notebook.color,
                      ),
                      CountChip(
                        icon: Icons.task_alt,
                        label:
                            '$pendingCount '
                            '${pendingCount == 1 ? 'pendiente' : 'pendientes'}',
                        color: notebook.color,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NewNotebookTile extends StatelessWidget {
  const _NewNotebookTile();

  @override
  Widget build(BuildContext context) {
    final colors = BrownieColors.of(context);
    return BrownieTile(
      onTap: () => showNotebookForm(context),
      color: colors.surfaceVariant.withAlpha(120),
      border: Border.all(color: colors.primary.withAlpha(90), width: 1.5),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: colors.primary.withAlpha(30),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.add, color: colors.primary, size: 28),
            ),
            const SizedBox(height: 10),
            Text(
              'Nuevo cuaderno',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: colors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void _openSettings(BuildContext context, AppProvider provider) {
  showModalBottomSheet<void>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Acerca de'),
            subtitle: const Text('Código abierto. Tus datos se guardan solo en este dispositivo.'),
            onTap: () {
              Navigator.pop(ctx);
              showAboutDialog(
                context: context,
                applicationName: 'BrownieNote',
                applicationLegalese: 'Código abierto. Tus datos se guardan solo en este dispositivo.',
              );
            },
          ),
        ],
      ),
    ),
  );
}
