import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../widgets/note_tiles.dart';
import 'note_editor_screen.dart';

/// Notas de un conjunto dentro de un cuaderno
class NoteSetScreen extends StatelessWidget {
  final String notebookId;
  final String setId;

  const NoteSetScreen({
    super.key,
    required this.notebookId,
    required this.setId,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final colors = BrownieColors.of(context);

    final notebook = provider.notebookById(notebookId);
    final set = notebook?.setById(setId);
    if (notebook == null || set == null) {
      // El conjunto o el cuaderno se eliminó mientras esta pantalla estaba abierta
      return Scaffold(backgroundColor: colors.bg);
    }
    final notes = provider.notesInSet(notebookId, setId);

    return Scaffold(
      backgroundColor: colors.bg,
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(
              8,
              MediaQuery.paddingOf(context).top + 16,
              8,
              20,
            ),
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
                    child: Text(set.emoji, style: const TextStyle(fontSize: 28)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        set.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${notebook.emoji} ${notebook.name}',
                        style: TextStyle(
                          color: Colors.white.withAlpha(200),
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.white),
                  onSelected: (v) async {
                    if (v == 'edit') {
                      showNoteSetForm(context, notebook, set: set);
                    } else if (v == 'delete') {
                      final deleted =
                          await confirmDeleteNoteSet(context, notebook, set);
                      if (deleted && context.mounted) Navigator.pop(context);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Editar conjunto')),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(
                        'Eliminar',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: notes.isEmpty
                ? const EmptyState(
                    emoji: '📄',
                    title: 'Conjunto vacío',
                    subtitle: 'Toca el botón + para crear\nuna nota aquí',
                  )
                : GridView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                    gridDelegate: brownieTileGrid(),
                    children: [
                      for (final n in notes)
                        NoteTile(notebook: notebook, note: n),
                    ],
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => NoteEditorScreen(
              notebookId: notebook.id,
              notebookColor: notebook.color,
              setId: set.id,
            ),
          ),
        ),
        backgroundColor: notebook.color,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.note_add_outlined),
        label: const Text('Nueva nota'),
      ),
    );
  }
}
