import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';

/// Abre el formulario para crear (o editar, si se pasa [notebook]) un cuaderno
Future<void> showNotebookForm(BuildContext context, {Notebook? notebook}) async {
  await showDialog(
    context: context,
    builder: (_) => _NotebookFormDialog(existingNotebook: notebook),
  );
}

/// Pide confirmación y elimina el cuaderno con todas sus notas y tareas.
/// Devuelve true si se eliminó.
Future<bool> confirmDeleteNotebook(BuildContext context, Notebook nb) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Eliminar cuaderno'),
      content: Text(
          '¿Eliminar "${nb.name}"?\nSe eliminarán todas sus notas y tareas.'),
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
  await context.read<AppProvider>().deleteNotebook(nb.id);
  return true;
}

// ─── Notebook Form Dialog ────────────────────────────────────────────────────

class _NotebookFormDialog extends StatefulWidget {
  final Notebook? existingNotebook;
  const _NotebookFormDialog({this.existingNotebook});

  @override
  State<_NotebookFormDialog> createState() => _NotebookFormDialogState();
}

class _NotebookFormDialogState extends State<_NotebookFormDialog> {
  late TextEditingController _nameCtrl;
  late TextEditingController _subjectCtrl;
  late Color _color;
  late String _emoji;

  @override
  void initState() {
    super.initState();
    final nb = widget.existingNotebook;
    _nameCtrl = TextEditingController(text: nb?.name ?? '');
    _subjectCtrl = TextEditingController(text: nb?.subject ?? '');
    _color = nb?.color ?? AppTheme.subjectColors.first;
    _emoji = nb?.emoji ?? AppTheme.subjectEmojis.first;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _subjectCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final provider = context.read<AppProvider>();
    final name = _nameCtrl.text.trim();
    final subject = _subjectCtrl.text.trim();
    if (name.isEmpty) return;

    if (widget.existingNotebook != null) {
      await provider.updateNotebook(
          widget.existingNotebook!.id, name, subject, _color, _emoji);
    } else {
      await provider.addNotebook(name, subject, _color, _emoji);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final colors = BrownieColors.of(context);

    return Dialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(
                  widget.existingNotebook != null
                      ? 'Editar cuaderno'
                      : 'Nuevo cuaderno',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: colors.text,
                  ),
                ),
                const SizedBox(height: 20),

                // Emoji picker
                Text('Ícono',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: colors.subtext)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 48,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: AppTheme.subjectEmojis.length,
                    itemBuilder: (_, i) {
                      final e = AppTheme.subjectEmojis[i];
                      return GestureDetector(
                        onTap: () => setState(() => _emoji = e),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 44,
                          height: 44,
                          margin: const EdgeInsets.only(right: 6),
                          decoration: BoxDecoration(
                            color: _emoji == e
                                ? _color.withAlpha(40)
                                : colors.surfaceVariant,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _emoji == e
                                  ? _color
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: Center(
                              child: Text(e,
                                  style:
                                      const TextStyle(fontSize: 22))),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),

                // Color picker
                Text('Color',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: colors.subtext)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: AppTheme.subjectColors.map((c) {
                    return GestureDetector(
                      onTap: () => setState(() => _color = c),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _color == c
                                ? Colors.white
                                : Colors.transparent,
                            width: 3,
                          ),
                          boxShadow: _color == c
                              ? [
                                  BoxShadow(
                                      color: c.withAlpha(120),
                                      blurRadius: 10,
                                      spreadRadius: 2)
                                ]
                              : [],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // Name
                Text('Nombre del cuaderno',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: colors.subtext)),
                const SizedBox(height: 6),
                TextField(
                  controller: _nameCtrl,
                  decoration: InputDecoration(
                    hintText: 'Ej: Matemáticas',
                    hintStyle: TextStyle(color: colors.subtext),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: colors.divider)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            BorderSide(color: _color, width: 2)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                  ),
                ),
                const SizedBox(height: 12),

                // Subject
                Text('Materia / Categoría',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: colors.subtext)),
                const SizedBox(height: 6),
                TextField(
                  controller: _subjectCtrl,
                  decoration: InputDecoration(
                    hintText: 'Ej: Álgebra Lineal, 3er semestre...',
                    hintStyle: TextStyle(color: colors.subtext),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: colors.divider)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            BorderSide(color: _color, width: 2)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                  ),
                ),
                const SizedBox(height: 24),

                // Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _save,
                      style: FilledButton.styleFrom(
                          backgroundColor: _color,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10))),
                      child: Text(
                        widget.existingNotebook != null
                            ? 'Guardar'
                            : 'Crear cuaderno',
                        style:
                            const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
