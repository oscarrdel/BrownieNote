import 'package:flutter/material.dart';

import 'note_block.dart';

export 'note_block.dart';

/// Conjunto de notas dentro de un cuaderno (como una carpeta).
/// Se guarda dentro del cuaderno.
class NoteSet {
  final String id;
  String name;
  String emoji;
  DateTime createdAt;

  NoteSet({
    required this.id,
    required this.name,
    required this.emoji,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'emoji': emoji,
    'createdAt': createdAt.toIso8601String(),
  };

  factory NoteSet.fromJson(Map<String, dynamic> json) => NoteSet(
    id: json['id'],
    name: json['name'],
    emoji: json['emoji'] ?? '📁',
    createdAt: DateTime.parse(json['createdAt']),
  );
}

/// Modelo de un Cuaderno (Materia)
class Notebook {
  final String id;
  String name;
  String subject;
  Color color;
  String emoji;
  List<NoteSet> sets;
  DateTime createdAt;
  DateTime updatedAt;

  Notebook({
    required this.id,
    required this.name,
    required this.subject,
    required this.color,
    required this.emoji,
    List<NoteSet>? sets,
    required this.createdAt,
    DateTime? updatedAt,
  }) : sets = sets ?? [],
       updatedAt = updatedAt ?? createdAt;

  NoteSet? setById(String? id) {
    for (final s in sets) {
      if (s.id == id) return s;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'subject': subject,
    'color': color.toARGB32(),
    'emoji': emoji,
    'sets': sets.map((s) => s.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory Notebook.fromJson(Map<String, dynamic> json) {
    final createdAt = DateTime.parse(json['createdAt']);
    return Notebook(
      id: json['id'],
      name: json['name'],
      subject: json['subject'],
      color: Color(json['color']),
      emoji: json['emoji'],
      sets: [
        for (final s in (json['sets'] as List? ?? [])) NoteSet.fromJson(s),
      ],
      createdAt: createdAt,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : createdAt,
    );
  }
}

/// Modelo de una Nota
class Note {
  final String id;
  String notebookId;

  /// Conjunto al que pertenece; null = nota suelta en el cuaderno
  String? setId;
  String title;

  /// Texto plano derivado de [blocks], usado para vistas previas
  String content;
  List<NoteBlock> blocks;
  DateTime createdAt;
  DateTime updatedAt;
  List<String> tags;

  Note({
    required this.id,
    required this.notebookId,
    this.setId,
    required this.title,
    required this.content,
    required this.blocks,
    required this.createdAt,
    required this.updatedAt,
    this.tags = const [],
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'notebookId': notebookId,
    if (setId != null) 'setId': setId,
    'title': title,
    'content': content,
    'blocks': blocks.map((b) => b.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'tags': tags,
  };

  factory Note.fromJson(Map<String, dynamic> json) => Note(
    id: json['id'],
    notebookId: json['notebookId'],
    setId: json['setId'],
    title: json['title'],
    content: json['content'],
    blocks: json['blocks'] != null
        ? (json['blocks'] as List).map((b) => NoteBlock.fromJson(b)).toList()
        : NoteBlock.fromPlainText(json['content'] ?? ''),
    createdAt: DateTime.parse(json['createdAt']),
    updatedAt: DateTime.parse(json['updatedAt']),
    tags: List<String>.from(json['tags'] ?? []),
  );
}

/// Prioridad de tarea
enum TaskPriority { low, medium, high }

/// Modelo de una Tarea
class Task {
  final String id;
  String notebookId;
  String title;
  String description;
  DateTime? dueDate;
  bool isCompleted;
  TaskPriority priority;
  DateTime createdAt;
  DateTime updatedAt;
  List<Attachment> attachments;

  Task({
    required this.id,
    required this.notebookId,
    required this.title,
    this.description = '',
    this.dueDate,
    this.isCompleted = false,
    this.priority = TaskPriority.medium,
    required this.createdAt,
    DateTime? updatedAt,
    this.attachments = const [],
  }) : updatedAt = updatedAt ?? createdAt;

  /// Una fecha sin hora (medianoche) vence al terminar ese día
  bool get isOverdue {
    if (dueDate == null || isCompleted) return false;
    final d = dueDate!;
    final deadline = d.hour == 0 && d.minute == 0
        ? DateTime(d.year, d.month, d.day, 23, 59, 59)
        : d;
    return deadline.isBefore(DateTime.now());
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'notebookId': notebookId,
    'title': title,
    'description': description,
    'dueDate': dueDate?.toIso8601String(),
    'isCompleted': isCompleted,
    'priority': priority.index,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'attachments': attachments.map((a) => a.toJson()).toList(),
  };

  factory Task.fromJson(Map<String, dynamic> json) {
    final createdAt = DateTime.parse(json['createdAt']);
    return Task(
      id: json['id'],
      notebookId: json['notebookId'],
      title: json['title'],
      description: json['description'] ?? '',
      dueDate: json['dueDate'] != null ? DateTime.parse(json['dueDate']) : null,
      isCompleted: json['isCompleted'] ?? false,
      priority: TaskPriority.values[json['priority'] ?? 1],
      createdAt: createdAt,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : createdAt,
      attachments: [
        for (final a in (json['attachments'] as List? ?? []))
          Attachment.fromJson(a),
      ],
    );
  }
}

/// Archivo adjunto a una tarea (imagen, PDF, documento...)
class Attachment {
  final String id;
  String name;

  /// Ruta en disco (móvil/escritorio)
  String? path;

  /// Contenido en base64 (web)
  String? data;
  int size;
  DateTime addedAt;

  Attachment({
    required this.id,
    required this.name,
    this.path,
    this.data,
    required this.size,
    required this.addedAt,
  });

  String get extension =>
      name.contains('.') ? name.split('.').last.toLowerCase() : '';

  bool get isImage =>
      const {'png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp'}.contains(extension);

  /// Tamaño legible: "340 KB", "2.1 MB"
  String get sizeLabel {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).round()} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    if (path != null) 'path': path,
    if (data != null) 'data': data,
    'size': size,
    'addedAt': addedAt.toIso8601String(),
  };

  factory Attachment.fromJson(Map<String, dynamic> json) => Attachment(
    id: json['id'],
    name: json['name'],
    path: json['path'],
    data: json['data'],
    size: json['size'] ?? 0,
    addedAt: DateTime.parse(json['addedAt']),
  );
}
