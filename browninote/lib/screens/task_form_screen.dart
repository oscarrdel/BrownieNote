import '../config/features.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../models/models.dart';
import '../services/file_storage.dart';
import '../services/task_urgency.dart';
import '../theme/app_theme.dart';
import '../widgets/attachments.dart';

class TaskFormScreen extends StatefulWidget {
  final String notebookId;
  final Color notebookColor;
  final Task? existingTask;

  const TaskFormScreen({
    super.key,
    required this.notebookId,
    required this.notebookColor,
    this.existingTask,
  });

  @override
  State<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends State<TaskFormScreen> {
  late TextEditingController _titleCtrl;
  late TextEditingController _descCtrl;
  DateTime? _dueDate;
  TaskPriority _priority = TaskPriority.medium;
  late List<Attachment> _attachments;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    final task = widget.existingTask;
    _titleCtrl = TextEditingController(text: task?.title ?? '');
    _descCtrl = TextEditingController(text: task?.description ?? '');
    _dueDate = task?.dueDate;
    _priority = task?.priority ?? TaskPriority.medium;
    _attachments = List.of(task?.attachments ?? []);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 3)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.fromSeed(seedColor: widget.notebookColor),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      // Conserva la hora si ya había una
      setState(
        () => _dueDate = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _dueDate?.hour ?? 0,
          _dueDate?.minute ?? 0,
        ),
      );
    }
  }

  bool get _hasTime => _dueDate != null && UrgencyEngine.hasTime(_dueDate!);

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _hasTime
          ? TimeOfDay.fromDateTime(_dueDate!)
          : const TimeOfDay(hour: 8, minute: 0),
    );
    if (picked != null && _dueDate != null) {
      // 0:00 se usa para "sin hora", así que medianoche se guarda como 23:59
      final midnight = picked.hour == 0 && picked.minute == 0;
      setState(
        () => _dueDate = DateTime(
          _dueDate!.year,
          _dueDate!.month,
          _dueDate!.day,
          midnight ? 23 : picked.hour,
          midnight ? 59 : picked.minute,
        ),
      );
    }
  }

  Future<void> _save() async {
    final provider = context.read<AppProvider>();
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El título no puede estar vacío')),
      );
      return;
    }

    if (widget.existingTask != null) {
      await provider.updateTask(
        widget.existingTask!.id,
        title: title,
        description: _descCtrl.text.trim(),
        dueDate: _dueDate,
        clearDueDate: _dueDate == null,
        priority: _priority,
        attachments: _attachments,
      );
    } else {
      await provider.addTask(
        widget.notebookId,
        title,
        description: _descCtrl.text.trim(),
        dueDate: _dueDate,
        priority: _priority,
        attachments: _attachments,
      );
    }
    if (mounted) Navigator.pop(context);
  }

  // ─── Archivos ─────────────────────────────────────────────────────────────

  /// En web todo se guarda en el almacenamiento del navegador, que es pequeño
  static const _webMaxBytes = 2 * 1024 * 1024;

  Future<void> _addFiles(Future<List<ChosenFile>> Function() pick) async {
    final List<ChosenFile> picked;
    try {
      picked = await pick();
    } catch (e) {
      _snack('No se pudo agregar el archivo: $e');
      return;
    }
    if (picked.isEmpty) return;

    setState(() => _uploading = true);
    for (final file in picked) {
      if (kIsWeb && file.bytes.length > _webMaxBytes) {
        _snack('"${file.name}" es muy grande para la versión web (máx. 2 MB)');
        continue;
      }
      final ref = await FileStorage.save(
        file.bytes,
        file.name,
        folder: 'task_files',
      );
      _attachments.add(
        Attachment(
          id: const Uuid().v4(),
          name: file.name,
          path: ref.path,
          data: ref.data,
          size: file.bytes.length,
          addedAt: DateTime.now(),
        ),
      );
    }
    if (mounted) setState(() => _uploading = false);
  }

  Future<void> _pasteImage() => _addFiles(() async {
    final image = await FileStorage.pasteImage();
    if (image == null) _snack('No hay ninguna imagen en el portapapeles');
    return [?image];
  });

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final colors = BrownieColors.of(context);
    final isEditing = widget.existingTask != null;

    final priorityData = [
      ('Baja', TaskPriority.low, const Color(0xFF4EE5B0)),
      ('Media', TaskPriority.medium, const Color(0xFFE5A84E)),
      ('Alta', TaskPriority.high, const Color(0xFFE5524E)),
    ];

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        backgroundColor: widget.notebookColor.withAlpha(200),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          isEditing ? 'Editar tarea' : 'Nueva tarea',
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: _save,
            icon: const Icon(
              Icons.save_outlined,
              color: Colors.white,
              size: 18,
            ),
            label: const Text(
              'Guardar',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Título
            _FieldLabel(label: 'Tarea'),
            const SizedBox(height: 6),
            _StyledTextField(
              controller: _titleCtrl,
              hint: 'Ej: Estudiar para el examen de Matemáticas...',
              fontSize: 16,
            ),
            const SizedBox(height: 20),

            // Descripción
            _FieldLabel(label: 'Descripción (opcional)'),
            const SizedBox(height: 6),
            _StyledTextField(
              controller: _descCtrl,
              hint: 'Más detalles sobre la tarea...',
              minLines: 3,
            ),
            const SizedBox(height: 20),

            // Fecha de entrega
            _FieldLabel(label: 'Fecha de entrega'),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.divider),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.event_outlined,
                      color: widget.notebookColor,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _dueDate == null
                          ? 'Seleccionar fecha...'
                          : '${_dueDate!.day}/${_dueDate!.month}/${_dueDate!.year}',
                      style: TextStyle(
                        color: _dueDate == null ? colors.subtext : colors.text,
                        fontSize: 14,
                        fontWeight: _dueDate != null
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                    const Spacer(),
                    if (_dueDate != null)
                      GestureDetector(
                        onTap: () => setState(() => _dueDate = null),
                        child: Icon(
                          Icons.close,
                          size: 16,
                          color: colors.subtext,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (_dueDate != null) ...[
              const SizedBox(height: 10),
              GestureDetector(
                onTap: _pickTime,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colors.divider),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.schedule,
                        color: widget.notebookColor,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _hasTime
                            ? 'Hora de entrega: ${TimeOfDay.fromDateTime(_dueDate!).format(context)}'
                            : 'Hora de entrega (opcional)',
                        style: TextStyle(
                          color: _hasTime ? colors.text : colors.subtext,
                          fontSize: 14,
                          fontWeight: _hasTime
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                      const Spacer(),
                      if (_hasTime)
                        GestureDetector(
                          onTap: () => setState(
                            () => _dueDate = DateTime(
                              _dueDate!.year,
                              _dueDate!.month,
                              _dueDate!.day,
                            ),
                          ),
                          child: Icon(
                            Icons.close,
                            size: 16,
                            color: colors.subtext,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),

            // Prioridad
            _FieldLabel(label: 'Prioridad'),
            const SizedBox(height: 10),
            Row(
              children: priorityData.map((pd) {
                final isSelected = _priority == pd.$2;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _priority = pd.$2),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? pd.$3.withAlpha(40)
                              : colors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? pd.$3 : colors.divider,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: pd.$3,
                                shape: BoxShape.circle,
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: pd.$3.withAlpha(100),
                                          blurRadius: 8,
                                          spreadRadius: 2,
                                        ),
                                      ]
                                    : [],
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              pd.$1,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isSelected ? pd.$3 : colors.subtext,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            _UrgencyPreview(
              urgency: UrgencyEngine.evaluate(
                Task(
                  id: '',
                  notebookId: widget.notebookId,
                  title: '',
                  dueDate: _dueDate,
                  priority: _priority,
                  createdAt: DateTime.now(),
                ),
              ),
            ),
            const SizedBox(height: 24),

            if (taskAttachmentsEnabled) ...[
              // Archivos
              _FieldLabel(label: 'Archivos e imágenes'),
              const SizedBox(height: 4),
              Text(
                'Instrucciones, rúbricas, fotos del pizarrón... '
                'Ábrelos directo desde la tarea.',
                style: TextStyle(fontSize: 12, color: colors.subtext),
              ),
              const SizedBox(height: 10),
              if (_attachments.isNotEmpty) ...[
                AttachmentGrid(
                  attachments: _attachments,
                  onRemove: (a) => setState(() => _attachments.remove(a)),
                ),
                const SizedBox(height: 12),
              ],
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _uploading
                        ? null
                        : () => _addFiles(FileStorage.pickFiles),
                    icon: const Icon(Icons.attach_file, size: 18),
                    label: const Text('Agregar archivo'),
                  ),
                  if (FileStorage.canUseCamera)
                    OutlinedButton.icon(
                      onPressed: _uploading
                          ? null
                          : () => _addFiles(() async {
                              final photo = await FileStorage.pickImage(
                                ImageSource.camera,
                              );
                              return [?photo];
                            }),
                      icon: const Icon(Icons.photo_camera_outlined, size: 18),
                      label: const Text('Tomar foto'),
                    ),
                  OutlinedButton.icon(
                    onPressed: _uploading ? null : _pasteImage,
                    icon: const Icon(Icons.content_paste, size: 18),
                    label: const Text('Pegar imagen'),
                  ),
                  if (_uploading)
                    const Padding(
                      padding: EdgeInsets.all(8),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

/// Muestra qué urgencia real tendrá la tarea con la fecha y prioridad elegidas
class _UrgencyPreview extends StatelessWidget {
  final TaskUrgency urgency;
  const _UrgencyPreview({required this.urgency});

  @override
  Widget build(BuildContext context) {
    final colors = BrownieColors.of(context);
    final level = urgency.level;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: level.color.withAlpha(25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: level.color.withAlpha(90)),
      ),
      child: Row(
        children: [
          Text(level.emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Urgencia real: ${level.label}',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: level.color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  urgency.reason ?? level.description,
                  style: TextStyle(fontSize: 12, color: colors.subtext),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;
  const _FieldLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    final colors = BrownieColors.of(context);
    return Text(
      label,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: colors.subtext,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _StyledTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int minLines;
  final double fontSize;

  const _StyledTextField({
    required this.controller,
    required this.hint,
    this.minLines = 1,
    this.fontSize = 14,
  });

  @override
  Widget build(BuildContext context) {
    final colors = BrownieColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.divider),
      ),
      child: TextField(
        controller: controller,
        style: TextStyle(fontSize: fontSize, color: colors.text),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: colors.subtext, fontSize: fontSize),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
        minLines: minLines,
        maxLines: minLines > 1 ? null : 1,
        keyboardType: minLines > 1
            ? TextInputType.multiline
            : TextInputType.text,
      ),
    );
  }
}
