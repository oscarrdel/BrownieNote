import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/models.dart';

class AppProvider extends ChangeNotifier {
  static const _notebooksKey = 'notebooks';
  static const _notesKey = 'notes';
  static const _tasksKey = 'tasks';

  final _uuid = const Uuid();

  List<Notebook> _notebooks = [];
  List<Note> _notes = [];
  List<Task> _tasks = [];

  DateTime _selectedCalendarDay = DateTime.now();

  List<Notebook> get notebooks => _notebooks;
  List<Note> get notes => _notes;
  List<Task> get tasks => _tasks;
  DateTime get selectedCalendarDay => _selectedCalendarDay;

  Task? taskById(String id) {
    for (final t in _tasks) {
      if (t.id == id) return t;
    }
    return null;
  }

  Notebook? notebookById(String id) {
    for (final nb in _notebooks) {
      if (nb.id == id) return nb;
    }
    return null;
  }

  List<Note> notesForNotebook(String notebookId) =>
      _notes.where((n) => n.notebookId == notebookId).toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  /// Notas sueltas del cuaderno. Una nota cuyo conjunto ya no existe (por
  /// ejemplo, se borró en otro dispositivo) también se muestra aquí.
  List<Note> looseNotes(Notebook notebook) => notesForNotebook(notebook.id)
      .where((n) => notebook.setById(n.setId) == null)
      .toList();

  List<Note> notesInSet(String notebookId, String setId) =>
      notesForNotebook(notebookId).where((n) => n.setId == setId).toList();

  List<Task> tasksForNotebook(String notebookId) =>
      _tasks.where((t) => t.notebookId == notebookId).toList()
        ..sort((a, b) => a.isCompleted ? 1 : -1);

  List<Task> tasksForDay(DateTime day) => _tasks
      .where(
        (t) =>
            t.dueDate != null &&
            t.dueDate!.year == day.year &&
            t.dueDate!.month == day.month &&
            t.dueDate!.day == day.day,
      )
      .toList();

  List<Note> notesForDay(DateTime day) => _notes
      .where(
        (n) =>
            n.createdAt.year == day.year &&
            n.createdAt.month == day.month &&
            n.createdAt.day == day.day,
      )
      .toList();

  Set<DateTime> get daysWithEvents {
    final days = <DateTime>{};
    for (final t in _tasks) {
      if (t.dueDate != null) {
        days.add(DateTime(t.dueDate!.year, t.dueDate!.month, t.dueDate!.day));
      }
    }
    for (final n in _notes) {
      days.add(DateTime(n.createdAt.year, n.createdAt.month, n.createdAt.day));
    }
    return days;
  }

  int get pendingTasksCount => _tasks.where((t) => !t.isCompleted).length;
  int get overdueTasksCount => _tasks.where((t) => t.isOverdue).length;

  Future<void> loadData() async {
    try {
      await _readLocal();
    } catch (e) {
      // Datos dañados: la app arranca vacía en vez de no abrir.
      debugPrint('No se pudieron leer los datos guardados: $e');
    }
    notifyListeners();
  }

  Future<void> _readLocal() async {
    final prefs = await SharedPreferences.getInstance();

    final notebooksJson = prefs.getString(_notebooksKey);
    if (notebooksJson != null) {
      final list = jsonDecode(notebooksJson) as List;
      _notebooks = list.map((e) => Notebook.fromJson(e)).toList();
    }

    final notesJson = prefs.getString(_notesKey);
    if (notesJson != null) {
      final list = jsonDecode(notesJson) as List;
      _notes = list.map((e) => Note.fromJson(e)).toList();
    }

    final tasksJson = prefs.getString(_tasksKey);
    if (tasksJson != null) {
      final list = jsonDecode(tasksJson) as List;
      _tasks = list.map((e) => Task.fromJson(e)).toList();
    }

    notifyListeners();
  }

  Future<void> _save() => _writeLocal();

  T? _find<T>(List<T> list, bool Function(T) test) {
    for (final e in list) {
      if (test(e)) return e;
    }
    return null;
  }

  Future<void> _writeLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _notebooksKey,
      jsonEncode(_notebooks.map((n) => n.toJson()).toList()),
    );
    await prefs.setString(
      _notesKey,
      jsonEncode(_notes.map((n) => n.toJson()).toList()),
    );
    await prefs.setString(
      _tasksKey,
      jsonEncode(_tasks.map((t) => t.toJson()).toList()),
    );
  }

  // ─── Notebooks ────────────────────────────────────────────────────────────

  Future<void> addNotebook(
    String name,
    String subject,
    Color color,
    String emoji,
  ) async {
    final nb = Notebook(
      id: _uuid.v4(),
      name: name,
      subject: subject,
      color: color,
      emoji: emoji,
      createdAt: DateTime.now(),
    );
    _notebooks.add(nb);
    await _save();
    notifyListeners();
  }

  Future<void> updateNotebook(
    String id,
    String name,
    String subject,
    Color color,
    String emoji,
  ) async {
    final idx = _notebooks.indexWhere((n) => n.id == id);
    if (idx != -1) {
      _notebooks[idx]
        ..name = name
        ..subject = subject
        ..color = color
        ..emoji = emoji
        ..updatedAt = DateTime.now();
      await _save();
      notifyListeners();
    }
  }

  Future<void> deleteNotebook(String id) async {
    _notebooks.removeWhere((n) => n.id == id);
    _notes.removeWhere((n) => n.notebookId == id);
    _tasks.removeWhere((t) => t.notebookId == id);
    await _save();
    notifyListeners();
  }

  // ─── Note sets ────────────────────────────────────────────────────────────

  Future<NoteSet?> addNoteSet(String notebookId, String name, String emoji) async {
    final nb = notebookById(notebookId);
    if (nb == null) return null;
    final set = NoteSet(
      id: _uuid.v4(),
      name: name,
      emoji: emoji,
      createdAt: DateTime.now(),
    );
    nb.sets.add(set);
    nb.updatedAt = DateTime.now();
    await _save();
    notifyListeners();
    return set;
  }

  Future<void> updateNoteSet(
    String notebookId,
    String setId,
    String name,
    String emoji,
  ) async {
    final nb = notebookById(notebookId);
    final set = nb?.setById(setId);
    if (nb == null || set == null) return;
    set
      ..name = name
      ..emoji = emoji;
    nb.updatedAt = DateTime.now();
    await _save();
    notifyListeners();
  }

  /// Borra el conjunto. Sus notas no se borran: quedan sueltas en el cuaderno.
  Future<void> deleteNoteSet(String notebookId, String setId) async {
    final nb = notebookById(notebookId);
    if (nb == null) return;
    final now = DateTime.now();
    for (final n in notesInSet(notebookId, setId)) {
      n
        ..setId = null
        ..updatedAt = now;
    }
    nb.sets.removeWhere((s) => s.id == setId);
    nb.updatedAt = now;
    await _save();
    notifyListeners();
  }

  /// Mueve una nota a un conjunto, o la deja suelta si [setId] es null.
  Future<void> moveNote(String noteId, String? setId) async {
    final note = _find(_notes, (n) => n.id == noteId);
    if (note == null || note.setId == setId) return;
    note
      ..setId = setId
      ..updatedAt = DateTime.now();
    await _save();
    notifyListeners();
  }

  // ─── Notes ────────────────────────────────────────────────────────────────

  Future<Note> addNote(
    String notebookId,
    String title,
    List<NoteBlock> blocks, {
    String? setId,
    List<String> tags = const [],
  }) async {
    final note = Note(
      id: _uuid.v4(),
      notebookId: notebookId,
      setId: setId,
      title: title,
      content: NoteBlock.toPlainText(blocks),
      blocks: blocks,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      tags: tags,
    );
    _notes.add(note);
    await _save();
    notifyListeners();
    return note;
  }

  Future<void> updateNote(
    String id,
    String title,
    List<NoteBlock> blocks, {
    List<String> tags = const [],
  }) async {
    final idx = _notes.indexWhere((n) => n.id == id);
    if (idx != -1) {
      _notes[idx]
        ..title = title
        ..content = NoteBlock.toPlainText(blocks)
        ..blocks = blocks
        ..tags = tags
        ..updatedAt = DateTime.now();
      await _save();
      notifyListeners();
    }
  }

  Future<void> deleteNote(String id) async {
    _notes.removeWhere((n) => n.id == id);
    await _save();
    notifyListeners();
  }

  // ─── Tasks ────────────────────────────────────────────────────────────────

  Future<Task> addTask(
    String notebookId,
    String title, {
    String description = '',
    DateTime? dueDate,
    TaskPriority priority = TaskPriority.medium,
    List<Attachment> attachments = const [],
  }) async {
    final task = Task(
      id: _uuid.v4(),
      notebookId: notebookId,
      title: title,
      description: description,
      dueDate: dueDate,
      priority: priority,
      attachments: attachments,
      createdAt: DateTime.now(),
    );
    _tasks.add(task);
    await _save();
    notifyListeners();
    return task;
  }

  Future<void> updateTask(
    String id, {
    String? title,
    String? description,
    DateTime? dueDate,
    bool clearDueDate = false,
    bool? isCompleted,
    TaskPriority? priority,
    List<Attachment>? attachments,
  }) async {
    final idx = _tasks.indexWhere((t) => t.id == id);
    if (idx != -1) {
      if (title != null) _tasks[idx].title = title;
      if (description != null) _tasks[idx].description = description;
      if (dueDate != null || clearDueDate) _tasks[idx].dueDate = dueDate;
      if (isCompleted != null) _tasks[idx].isCompleted = isCompleted;
      if (priority != null) _tasks[idx].priority = priority;
      if (attachments != null) _tasks[idx].attachments = attachments;
      _tasks[idx].updatedAt = DateTime.now();
      await _save();
      notifyListeners();
    }
  }

  Future<void> toggleTask(String id) async {
    final idx = _tasks.indexWhere((t) => t.id == id);
    if (idx != -1) {
      _tasks[idx].isCompleted = !_tasks[idx].isCompleted;
      _tasks[idx].updatedAt = DateTime.now();
      await _save();
      notifyListeners();
    }
  }

  Future<void> deleteTask(String id) async {
    _tasks.removeWhere((t) => t.id == id);
    await _save();
    notifyListeners();
  }

  // ─── Calendar ─────────────────────────────────────────────────────────────

  void setSelectedCalendarDay(DateTime day) {
    _selectedCalendarDay = day;
    notifyListeners();
  }

}
