import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/models.dart';
import '../services/task_urgency.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../widgets/note_tiles.dart';
import '../widgets/notebook_dialogs.dart';
import '../widgets/task_tile.dart';
import 'note_editor_screen.dart';
import 'task_form_screen.dart';

/// Notas y tareas de un cuaderno
class NotebookScreen extends StatelessWidget {
  final String notebookId;
  const NotebookScreen({super.key, required this.notebookId});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final colors = BrownieColors.of(context);

    final notebook = provider.notebookById(notebookId);
    if (notebook == null) {
      // El cuaderno se eliminó mientras esta pantalla estaba abierta
      return Scaffold(backgroundColor: colors.bg);
    }

    final notes = provider.notesForNotebook(notebook.id);
    final tasks = provider.tasksForNotebook(notebook.id);
    // Pendientes en el orden del sistema de urgencia
    final pendingTasks =
        UrgencyEngine.rank(tasks).map((u) => u.task).toList();
    final completedTasks = tasks.where((t) => t.isCompleted).toList();

    return Scaffold(
      backgroundColor: colors.bg,
      body: Column(
        children: [
          // ─── Header del cuaderno ──────────────────────────────────────────
          _NotebookHeader(notebook: notebook),

          // ─── Contenido ───────────────────────────────────────────────────
          Expanded(
            child: DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  // Tab bar
                  Container(
                    color: colors.surface,
                    child: TabBar(
                      labelColor: notebook.color,
                      unselectedLabelColor: colors.subtext,
                      indicatorColor: notebook.color,
                      indicatorWeight: 3,
                      tabs: [
                        Tab(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('📝 '),
                              Flexible(
                                child: Text(
                                  'Notas (${notes.length})',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Tab(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('✅ '),
                              Flexible(
                                child: Text(
                                  'Tareas (${pendingTasks.length})',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        // Tab de Notas
                        _NotesTab(notebook: notebook, provider: provider),
                        // Tab de Tareas
                        _TasksTab(
                          pendingTasks: pendingTasks,
                          completedTasks: completedTasks,
                          notebook: notebook,
                          provider: provider,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _HomeFAB(notebook: notebook),
    );
  }
}

// ─── Notebook Header ────────────────────────────────────────────────────────

class _NotebookHeader extends StatelessWidget {
  final Notebook notebook;
  const _NotebookHeader({required this.notebook});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
          8, MediaQuery.paddingOf(context).top + 16, 8, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            notebook.color.withAlpha(200),
            notebook.color.withAlpha(120),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          const BackButton(color: Colors.white),
          const SizedBox(width: 4),
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(40),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(notebook.emoji,
                  style: const TextStyle(fontSize: 28)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notebook.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  notebook.subject,
                  style: TextStyle(
                    color: Colors.white.withAlpha(200),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (v) async {
              if (v == 'edit') {
                showNotebookForm(context, notebook: notebook);
              } else if (v == 'delete') {
                final deleted = await confirmDeleteNotebook(context, notebook);
                if (deleted && context.mounted) Navigator.pop(context);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined, size: 16),
                    SizedBox(width: 8),
                    Text('Editar cuaderno'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, size: 16, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Eliminar', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Notes Tab ──────────────────────────────────────────────────────────────

/// Conjuntos primero y luego las notas sueltas, como carpetas y archivos
class _NotesTab extends StatelessWidget {
  final Notebook notebook;
  final AppProvider provider;

  const _NotesTab({required this.notebook, required this.provider});

  @override
  Widget build(BuildContext context) {
    final loose = provider.looseNotes(notebook);
    if (notebook.sets.isEmpty && loose.isEmpty) {
      return const EmptyState(
        emoji: '📄',
        title: 'Sin notas aún',
        subtitle: 'Toca el botón + para crear\ntu primera nota o un conjunto',
      );
    }

    return GridView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      gridDelegate: brownieTileGrid(),
      children: [
        for (final s in notebook.sets)
          NoteSetTile(
            notebook: notebook,
            set: s,
            noteCount: provider.notesInSet(notebook.id, s.id).length,
          ),
        for (final n in loose) NoteTile(notebook: notebook, note: n),
      ],
    );
  }
}

// ─── Tasks Tab ──────────────────────────────────────────────────────────────

class _TasksTab extends StatelessWidget {
  final List<Task> pendingTasks;
  final List<Task> completedTasks;
  final Notebook notebook;
  final AppProvider provider;

  const _TasksTab({
    required this.pendingTasks,
    required this.completedTasks,
    required this.notebook,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    final allTasks = [...pendingTasks, ...completedTasks];
    if (allTasks.isEmpty) {
      return const EmptyState(
        emoji: '✅',
        title: 'Sin tareas aún',
        subtitle: 'Toca el botón + para añadir\ntu primera tarea',
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (pendingTasks.isNotEmpty) ...[
          _SectionLabel(label: 'Pendientes', count: pendingTasks.length),
          ...pendingTasks.map((t) => TaskTile(
                task: t,
                notebook: notebook,
              )),
        ],
        if (completedTasks.isNotEmpty) ...[
          _SectionLabel(
              label: 'Completadas', count: completedTasks.length),
          ...completedTasks.map((t) => TaskTile(
                task: t,
                notebook: notebook,
              )),
        ],
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final int count;
  const _SectionLabel({required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    final colors = BrownieColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(
        '$label ($count)',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: colors.subtext,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ─── FAB con opciones ────────────────────────────────────────────────────────

class _HomeFAB extends StatefulWidget {
  final Notebook notebook;
  const _HomeFAB({required this.notebook});

  @override
  State<_HomeFAB> createState() => _HomeFABState();
}

class _HomeFABState extends State<_HomeFAB>
    with SingleTickerProviderStateMixin {
  bool _open = false;
  late AnimationController _ctrl;
  late Animation<double> _expand;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 250));
    _expand = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _open = !_open);
    if (_open) {
      _ctrl.forward();
    } else {
      _ctrl.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Mini FABs
        ScaleTransition(
          scale: _expand,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _MiniFAB(
                label: 'Nueva nota',
                icon: Icons.note_add_outlined,
                color: widget.notebook.color,
                onTap: () {
                  _toggle();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => NoteEditorScreen(
                        notebookId: widget.notebook.id,
                        notebookColor: widget.notebook.color,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
              _MiniFAB(
                label: 'Nuevo conjunto',
                icon: Icons.create_new_folder_outlined,
                color: widget.notebook.color,
                onTap: () {
                  _toggle();
                  showNoteSetForm(context, widget.notebook);
                },
              ),
              const SizedBox(height: 10),
              _MiniFAB(
                label: 'Nueva tarea',
                icon: Icons.add_task,
                color: widget.notebook.color,
                onTap: () {
                  _toggle();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TaskFormScreen(
                        notebookId: widget.notebook.id,
                        notebookColor: widget.notebook.color,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
        // Main FAB
        FloatingActionButton(
          onPressed: _toggle,
          backgroundColor: widget.notebook.color,
          foregroundColor: Colors.white,
          child: AnimatedRotation(
            turns: _open ? 0.125 : 0,
            duration: const Duration(milliseconds: 250),
            child: const Icon(Icons.add, size: 28),
          ),
        ),
      ],
    );
  }
}

class _MiniFAB extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _MiniFAB({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = BrownieColors.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colors.divider),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withAlpha(30),
                  blurRadius: 8,
                  offset: const Offset(0, 2))
            ],
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colors.text)),
        ),
        const SizedBox(width: 10),
        FloatingActionButton.small(
          onPressed: onTap,
          backgroundColor: color.withAlpha(220),
          foregroundColor: Colors.white,
          heroTag: label,
          child: Icon(icon, size: 20),
        ),
      ],
    );
  }
}
