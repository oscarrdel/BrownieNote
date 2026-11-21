import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/app_provider.dart';
import '../screens/note_editor_screen.dart';
import '../screens/note_set_screen.dart';
import '../theme/app_theme.dart';
import 'common_widgets.dart';

/// Tarjeta de un conjunto de notas, del mismo tamaño que la de un cuaderno
class NoteSetTile extends StatelessWidget {
  final Notebook notebook;
  final NoteSet set;
  final int noteCount;

  const NoteSetTile({
    super.key,
    required this.notebook,
    required this.set,
    required this.noteCount,
  });

  @override
  Widget build(BuildContext context) {
    final colors = BrownieColors.of(context);
    return BrownieTile(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              NoteSetScreen(notebookId: notebook.id, setId: set.id),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Portada tipo carpeta
          Container(
            height: 96,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  notebook.color.withAlpha(110),
                  notebook.color.withAlpha(60),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Stack(
              children: [
                // Pestaña de carpeta
                Positioned(
                  left: 16,
                  top: 0,
                  child: Container(
                    width: 44,
                    height: 8,
                    decoration: BoxDecoration(
                      color: notebook.color.withAlpha(170),
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(6),
                      ),
                    ),
                  ),
                ),
                Center(
                  child: Text(set.emoji, style: const TextStyle(fontSize: 40)),
                ),
                Positioned(
                  right: 0,
                  top: 0,
                  child: _SetMenu(notebook: notebook, set: set),
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
                    set.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: colors.text,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Conjunto',
                    style: TextStyle(fontSize: 12, color: colors.subtext),
                  ),
                  const Spacer(),
                  CountChip(
                    icon: Icons.note_outlined,
                    label: '$noteCount ${noteCount == 1 ? 'nota' : 'notas'}',
                    color: notebook.color,
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

class _SetMenu extends StatelessWidget {
  final Notebook notebook;
  final NoteSet set;
  const _SetMenu({required this.notebook, required this.set});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_horiz, color: BrownieColors.of(context).text),
      onSelected: (v) {
        if (v == 'edit') showNoteSetForm(context, notebook, set: set);
        if (v == 'delete') confirmDeleteNoteSet(context, notebook, set);
      },
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'edit', child: Text('Editar')),
        PopupMenuItem(
          value: 'delete',
          child: Text('Eliminar', style: TextStyle(color: Colors.red)),
        ),
      ],
    );
  }
}

/// Tarjeta de una nota, del mismo tamaño que la de un cuaderno
class NoteTile extends StatelessWidget {
  final Notebook notebook;
  final Note note;

  const NoteTile({super.key, required this.notebook, required this.note});

  @override
  Widget build(BuildContext context) {
    final colors = BrownieColors.of(context);
    return BrownieTile(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => NoteEditorScreen(
            notebookId: notebook.id,
            notebookColor: notebook.color,
            existingNote: note,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Franja superior, como el borde de una hoja
          Container(
            height: 44,
            padding: const EdgeInsets.only(left: 16),
            color: notebook.color.withAlpha(35),
            child: Row(
              children: [
                const Text('📝', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _formatDate(note.updatedAt),
                    style: TextStyle(fontSize: 11, color: colors.subtext),
                  ),
                ),
                _NoteMenu(notebook: notebook, note: note),
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
                    note.title.isEmpty ? 'Sin título' : note.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: colors.text,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: Text(
                      note.content,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: colors.subtext,
                      ),
                      overflow: TextOverflow.fade,
                    ),
                  ),
                  if (note.tags.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        for (final t in note.tags.take(2))
                          TagBadge(label: t, color: notebook.color),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatDate(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Ahora mismo';
    if (diff.inHours < 1) return 'Hace ${diff.inMinutes} min';
    if (diff.inDays < 1) return 'Hace ${diff.inHours} h';
    if (diff.inDays < 7) return 'Hace ${diff.inDays} días';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

class _NoteMenu extends StatelessWidget {
  final Notebook notebook;
  final Note note;
  const _NoteMenu({required this.notebook, required this.note});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_horiz, color: BrownieColors.of(context).subtext),
      onSelected: (v) {
        if (v == 'move') showMoveNoteDialog(context, notebook, note);
        if (v == 'delete') confirmDeleteNote(context, note);
      },
      itemBuilder: (_) => [
        if (notebook.sets.isNotEmpty || note.setId != null)
          const PopupMenuItem(value: 'move', child: Text('Mover a…')),
        const PopupMenuItem(
          value: 'delete',
          child: Text('Eliminar', style: TextStyle(color: Colors.red)),
        ),
      ],
    );
  }
}

// ─── Diálogos ────────────────────────────────────────────────────────────────

const _setEmojis = ['📁', '📂', '🗂️', '📚', '🧪', '📐', '🎨', '💡', '⭐', '📌'];

/// Crea un conjunto, o edita [set] si se pasa
Future<void> showNoteSetForm(
  BuildContext context,
  Notebook notebook, {
  NoteSet? set,
}) async {
  final nameCtrl = TextEditingController(text: set?.name ?? '');
  var emoji = set?.emoji ?? _setEmojis.first;

  final saved = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text(set == null ? 'Nuevo conjunto' : 'Editar conjunto'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final e in _setEmojis)
                  InkWell(
                    onTap: () => setState(() => emoji = e),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: emoji == e
                            ? notebook.color.withAlpha(40)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: emoji == e
                              ? notebook.color
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Text(e, style: const TextStyle(fontSize: 20)),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Nombre',
                hintText: 'Ej: Parcial 1, Apuntes de clase…',
              ),
              onSubmitted: (_) => Navigator.pop(ctx, true),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(set == null ? 'Crear' : 'Guardar'),
          ),
        ],
      ),
    ),
  );

  // Sin dispose: el diálogo aún usa el controller durante su animación de
  // cierre, y es un objeto pequeño que se libera solo.
  final name = nameCtrl.text.trim();
  if (saved != true || name.isEmpty || !context.mounted) return;

  final provider = context.read<AppProvider>();
  if (set == null) {
    await provider.addNoteSet(notebook.id, name, emoji);
  } else {
    await provider.updateNoteSet(notebook.id, set.id, name, emoji);
  }
}

/// Pide confirmación y borra el conjunto; sus notas quedan sueltas.
/// Devuelve true si se borró.
Future<bool> confirmDeleteNoteSet(
  BuildContext context,
  Notebook notebook,
  NoteSet set,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Eliminar conjunto'),
      content: Text(
        '¿Eliminar "${set.name}"?\n'
        'Sus notas no se borran: pasan a estar sueltas en el cuaderno.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return false;
  await context.read<AppProvider>().deleteNoteSet(notebook.id, set.id);
  return true;
}

/// Elige a qué conjunto mover la nota, o dejarla suelta
Future<void> showMoveNoteDialog(
  BuildContext context,
  Notebook notebook,
  Note note,
) async {
  // '' = suelta; null = canceló
  final target = await showDialog<String>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: const Text('Mover a…'),
      children: [
        _MoveOption(
          emoji: notebook.emoji,
          label: 'Suelta en ${notebook.name}',
          selected: notebook.setById(note.setId) == null,
          onTap: () => Navigator.pop(ctx, ''),
        ),
        for (final s in notebook.sets)
          _MoveOption(
            emoji: s.emoji,
            label: s.name,
            selected: note.setId == s.id,
            onTap: () => Navigator.pop(ctx, s.id),
          ),
      ],
    ),
  );
  if (target == null || !context.mounted) return;
  await context
      .read<AppProvider>()
      .moveNote(note.id, target.isEmpty ? null : target);
}

class _MoveOption extends StatelessWidget {
  final String emoji;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _MoveOption({
    required this.emoji,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SimpleDialogOption(
      onPressed: onTap,
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(child: Text(label)),
          if (selected) const Icon(Icons.check, size: 18),
        ],
      ),
    );
  }
}

Future<void> confirmDeleteNote(BuildContext context, Note note) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Eliminar nota'),
      content: Text(
        '¿Eliminar "${note.title.isEmpty ? 'Sin título' : note.title}"?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  await context.read<AppProvider>().deleteNote(note.id);
}
