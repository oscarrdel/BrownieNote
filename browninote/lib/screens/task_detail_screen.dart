import '../config/features.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/app_provider.dart';
import '../services/task_urgency.dart';
import '../theme/app_theme.dart';
import '../widgets/attachments.dart';
import 'task_form_screen.dart';

/// Vista de solo lectura de una tarea. Para editar hay un botón explícito.
class TaskDetailScreen extends StatelessWidget {
  final String taskId;
  const TaskDetailScreen({super.key, required this.taskId});

  static const _weekdays = [
    'lunes',
    'martes',
    'miércoles',
    'jueves',
    'viernes',
    'sábado',
    'domingo',
  ];
  static const _months = [
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];
  static const _priorityLabels = ['Baja', 'Media', 'Alta'];
  static const _priorityColors = [
    Color(0xFF4EE5B0),
    Color(0xFFE5A84E),
    Color(0xFFE5524E),
  ];

  static String _fullDate(DateTime d, {bool withTime = false}) {
    final date =
        '${_weekdays[d.weekday - 1]} ${d.day} de ${_months[d.month - 1]}'
        '${d.year != DateTime.now().year ? ' de ${d.year}' : ''}';
    return withTime
        ? '$date, ${d.hour}:${d.minute.toString().padLeft(2, '0')}'
        : date;
  }

  void _edit(BuildContext context, Task task, Notebook notebook) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TaskFormScreen(
          notebookId: notebook.id,
          notebookColor: notebook.color,
          existingTask: task,
        ),
      ),
    );
  }

  Future<void> _delete(BuildContext context, Task task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar tarea'),
        content: Text('¿Eliminar "${task.title}"?'),
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
    Navigator.pop(context);
    await context.read<AppProvider>().deleteTask(task.id);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final colors = BrownieColors.of(context);
    final task = provider.taskById(taskId);
    final notebook = task == null
        ? null
        : provider.notebookById(task.notebookId);
    if (task == null || notebook == null) {
      return Scaffold(backgroundColor: colors.bg);
    }

    final urgency = task.isCompleted ? null : UrgencyEngine.evaluate(task);

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        backgroundColor: notebook.color.withAlpha(200),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          '${notebook.emoji} ${notebook.name}',
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: Colors.white,
            fontSize: 17,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: FilledButton.icon(
              onPressed: () => _edit(context, task, notebook),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white.withAlpha(45),
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text(
                'Editar',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (v) {
              if (v == 'delete') _delete(context, task);
            },
            itemBuilder: (_) => const [
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Título
                SelectableText(
                  task.title,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: task.isCompleted ? colors.subtext : colors.text,
                    decoration: task.isCompleted
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
                const SizedBox(height: 14),

                // Hecha / pendiente
                task.isCompleted
                    ? OutlinedButton.icon(
                        onPressed: () => provider.toggleTask(task.id),
                        icon: Icon(Icons.check_circle, color: notebook.color),
                        label: const Text('Hecha · marcar como pendiente'),
                      )
                    : FilledButton.icon(
                        onPressed: () => provider.toggleTask(task.id),
                        style: FilledButton.styleFrom(
                          backgroundColor: notebook.color,
                        ),
                        icon: const Icon(Icons.check),
                        label: const Text(
                          'Marcar como hecha',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                const SizedBox(height: 20),

                // Datos clave
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    if (urgency != null)
                      _InfoCard(
                        label: 'Urgencia',
                        color: urgency.level.color,
                        value: '${urgency.level.emoji} ${urgency.level.label}',
                        detail: urgency.reason ?? urgency.level.description,
                      ),
                    _InfoCard(
                      label: 'Entrega',
                      color: urgency?.level.color ?? colors.subtext,
                      value: task.dueDate == null
                          ? 'Sin fecha'
                          : UrgencyEngine.dueLabel(task.dueDate!),
                      detail: task.dueDate == null
                          ? null
                          : _fullDate(
                              task.dueDate!,
                              withTime: UrgencyEngine.hasTime(task.dueDate!),
                            ),
                    ),
                    _InfoCard(
                      label: 'Prioridad',
                      color: _priorityColors[task.priority.index],
                      value: _priorityLabels[task.priority.index],
                      detail: 'La que le pusiste',
                    ),
                  ],
                ),

                // Descripción
                if (task.description.trim().isNotEmpty) ...[
                  const SizedBox(height: 28),
                  _SectionTitle(title: 'Descripción e instrucciones'),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: colors.divider),
                    ),
                    child: SelectableText(
                      task.description,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.6,
                        color: colors.text,
                      ),
                    ),
                  ),
                ],

                // Archivos
                if (taskAttachmentsEnabled && task.attachments.isNotEmpty) ...[
                  const SizedBox(height: 28),
                  _SectionTitle(
                    title: 'Archivos e imágenes (${task.attachments.length})',
                  ),
                  const SizedBox(height: 10),
                  AttachmentGrid(attachments: task.attachments),
                ],

                if (task.description.trim().isEmpty &&
                    task.attachments.isEmpty) ...[
                  const SizedBox(height: 28),
                  Text(
                    'Esta tarea no tiene descripción ni archivos. '
                    'Usa "Editar" para agregar instrucciones o documentos.',
                    style: TextStyle(color: colors.subtext, fontSize: 13),
                  ),
                ],

                const SizedBox(height: 28),
                Text(
                  'Creada el ${_fullDate(task.createdAt)}',
                  style: TextStyle(color: colors.subtext, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String label;
  final String value;
  final String? detail;
  final Color color;

  const _InfoCard({
    required this.label,
    required this.value,
    required this.color,
    this.detail,
  });

  @override
  Widget build(BuildContext context) {
    final colors = BrownieColors.of(context);
    return Container(
      constraints: const BoxConstraints(minWidth: 160, maxWidth: 240),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withAlpha(22),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 1,
              fontWeight: FontWeight.w700,
              color: colors.subtext,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          if (detail != null) ...[
            const SizedBox(height: 2),
            Text(
              detail!,
              style: TextStyle(fontSize: 12, color: colors.subtext),
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    final colors = BrownieColors.of(context);
    return Text(
      title,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w800,
        color: colors.subtext,
      ),
    );
  }
}
