import '../config/features.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/app_provider.dart';
import '../screens/task_detail_screen.dart';
import '../screens/task_form_screen.dart';
import '../services/task_urgency.dart';
import '../theme/app_theme.dart';
import 'common_widgets.dart';

/// Tarjeta de una tarea con su urgencia real
class TaskTile extends StatelessWidget {
  final Task task;
  final Notebook notebook;

  /// Muestra a qué cuaderno pertenece (útil en listas de varios cuadernos)
  final bool showNotebook;

  const TaskTile({
    super.key,
    required this.task,
    required this.notebook,
    this.showNotebook = false,
  });

  static const _priorityNames = ['low', 'medium', 'high'];
  static const _priorityLabels = ['Baja', 'Media', 'Alta'];

  @override
  Widget build(BuildContext context) {
    final colors = BrownieColors.of(context);
    final provider = context.read<AppProvider>();
    final urgency = task.isCompleted ? null : UrgencyEngine.evaluate(task);
    final levelColor = urgency?.level.color ?? colors.subtext;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: BrownieCard(
        padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
        // Tocar abre la vista de lectura; para editar está el botón ✏️
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => TaskDetailScreen(taskId: task.id)),
        ),
        child: Row(
          children: [
            // Barra de urgencia
            Container(
              width: 4,
              height: 40,
              decoration: BoxDecoration(
                color: urgency == null
                    ? Colors.transparent
                    : levelColor.withAlpha(
                        urgency.level == UrgencyLevel.none ? 60 : 255,
                      ),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 10),
            // Checkbox
            GestureDetector(
              onTap: () => provider.toggleTask(task.id),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: task.isCompleted ? notebook.color : Colors.transparent,
                  border: Border.all(
                    color: task.isCompleted ? notebook.color : colors.subtext,
                    width: 2,
                  ),
                ),
                child: task.isCompleted
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: task.isCompleted ? colors.subtext : colors.text,
                      decoration: task.isCompleted
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 10,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (showNotebook)
                        Text(
                          '${notebook.emoji} ${notebook.name}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: notebook.color,
                          ),
                        ),
                      if (task.dueDate != null)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              urgency?.isOverdue == true
                                  ? Icons.warning_amber_rounded
                                  : Icons.event,
                              size: 12,
                              color: levelColor,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              UrgencyEngine.dueLabel(task.dueDate!),
                              style: TextStyle(
                                fontSize: 11,
                                color: levelColor,
                                fontWeight:
                                    urgency?.level == UrgencyLevel.critical
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      if (taskAttachmentsEnabled && task.attachments.isNotEmpty)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.attach_file,
                              size: 12,
                              color: colors.subtext,
                            ),
                            Text(
                              '${task.attachments.length}',
                              style: TextStyle(
                                fontSize: 11,
                                color: colors.subtext,
                              ),
                            ),
                          ],
                        ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          PriorityDot(
                            priority: _priorityNames[task.priority.index],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _priorityLabels[task.priority.index],
                            style: TextStyle(
                              fontSize: 11,
                              color: colors.subtext,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (urgency?.reason != null) ...[
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(
                          urgency!.raised == false
                              ? Icons.south_east
                              : Icons.north_east,
                          size: 12,
                          color: levelColor,
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            urgency.reason!,
                            style: TextStyle(
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                              color: colors.subtext,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              tooltip: 'Editar tarea',
              icon: Icon(Icons.edit_outlined, size: 17, color: colors.subtext),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TaskFormScreen(
                    notebookId: notebook.id,
                    notebookColor: notebook.color,
                    existingTask: task,
                  ),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Eliminar tarea',
              icon: Icon(Icons.delete_outline, size: 17, color: colors.subtext),
              onPressed: () => provider.deleteTask(task.id),
            ),
          ],
        ),
      ),
    );
  }
}
