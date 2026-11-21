import 'package:flutter/material.dart';

import '../models/models.dart';

/// Urgencia real de una tarea, calculada a partir de la fecha de entrega y la
/// prioridad que le puso el usuario.
enum UrgencyLevel { critical, high, medium, low, none }

extension UrgencyLevelInfo on UrgencyLevel {
  String get label => switch (this) {
        UrgencyLevel.critical => 'Crítica',
        UrgencyLevel.high => 'Alta',
        UrgencyLevel.medium => 'Media',
        UrgencyLevel.low => 'Baja',
        UrgencyLevel.none => 'Sin fecha',
      };

  String get emoji => switch (this) {
        UrgencyLevel.critical => '🔥',
        UrgencyLevel.high => '⚡',
        UrgencyLevel.medium => '📌',
        UrgencyLevel.low => '🌱',
        UrgencyLevel.none => '🗂️',
      };

  String get description => switch (this) {
        UrgencyLevel.critical => 'Vencidas o para hoy/mañana. Hazlas ya.',
        UrgencyLevel.high => 'Se acerca la fecha. Empiézalas pronto.',
        UrgencyLevel.medium => 'Para esta semana. Ve avanzando.',
        UrgencyLevel.low => 'Todavía hay tiempo.',
        UrgencyLevel.none => 'Sin fecha de entrega.',
      };

  Color get color => switch (this) {
        UrgencyLevel.critical => const Color(0xFFE5524E),
        UrgencyLevel.high => const Color(0xFFE5734E),
        UrgencyLevel.medium => const Color(0xFFE5A84E),
        UrgencyLevel.low => const Color(0xFF3FBF94),
        UrgencyLevel.none => const Color(0xFF9B96C4),
      };
}

/// Resultado de evaluar una tarea
class TaskUrgency {
  final Task task;
  final UrgencyLevel level;

  /// Momento real de entrega (fin del día si la tarea no tiene hora)
  final DateTime? deadline;

  /// Menor = hacer primero
  final double score;

  /// Cuándo se entrega, en palabras ("Hoy, 8:00", "Mañana", "En 5 días")
  final String dueLabel;

  /// Por qué la urgencia real es distinta a la prioridad que se le puso
  final String? reason;

  /// true si la urgencia subió respecto a su prioridad, false si bajó
  final bool? raised;

  const TaskUrgency({
    required this.task,
    required this.level,
    required this.deadline,
    required this.score,
    required this.dueLabel,
    this.reason,
    this.raised,
  });

  bool get isOverdue => deadline != null && deadline!.isBefore(DateTime.now());
}

/// Ordena tareas como lo haría una persona con buen criterio:
///
/// 1. **Vencidas** primero: ya se pasó la fecha, hay que entregarlas.
/// 2. **Para hoy o mañana**: son críticas sin importar su prioridad. Una tarea
///    de prioridad baja que se entrega mañana va antes que una de prioridad
///    alta que se entrega en dos semanas. Entre ellas manda la hora de entrega.
/// 3. **El resto**: la prioridad "adelanta" la fecha. Una tarea de prioridad
///    alta se siente 3.5 días más cerca y una media 1.5 días, así que una alta
///    para dentro de 5 días va antes que una baja para dentro de 3.
/// 4. **Sin fecha** al final, ordenadas por prioridad.
class UrgencyEngine {
  static const _overdueBase = -100000.0;
  static const _criticalBase = -50000.0;
  static const _noDateBase = 100000.0;

  /// Días que "adelanta" cada prioridad
  static double _priorityBonusDays(TaskPriority p) => switch (p) {
        TaskPriority.high => 3.5,
        TaskPriority.medium => 1.5,
        TaskPriority.low => 0,
      };

  static UrgencyLevel _levelOf(TaskPriority p) => switch (p) {
        TaskPriority.high => UrgencyLevel.high,
        TaskPriority.medium => UrgencyLevel.medium,
        TaskPriority.low => UrgencyLevel.low,
      };

  /// Una fecha sin hora (medianoche) significa "durante ese día"
  static bool hasTime(DateTime due) => due.hour != 0 || due.minute != 0;

  static DateTime deadlineOf(DateTime due) =>
      hasTime(due) ? due : DateTime(due.year, due.month, due.day, 23, 59, 59);

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  static TaskUrgency evaluate(Task task, {DateTime? now}) {
    now ??= DateTime.now();
    final p = task.priority;

    if (task.dueDate == null) {
      return TaskUrgency(
        task: task,
        level: UrgencyLevel.none,
        deadline: null,
        score: _noDateBase - p.index * 1000,
        dueLabel: 'Sin fecha',
      );
    }

    final deadline = deadlineOf(task.dueDate!);
    final hoursLeft = deadline.difference(now).inMinutes / 60;
    final daysLeft = _day(deadline).difference(_day(now)).inDays;
    final label = dueLabel(task.dueDate!, now: now);

    // 1. Vencida: primero las de más prioridad, luego las que llevan más tiempo
    if (hoursLeft < 0) {
      return TaskUrgency(
        task: task,
        level: UrgencyLevel.critical,
        deadline: deadline,
        score: _overdueBase + (2 - p.index) * 1000 + hoursLeft.clamp(-999, 0),
        dueLabel: label,
        reason: 'Ya venció: entrégala cuanto antes',
        raised: true,
      );
    }

    // 2. Hoy o mañana: crítica sin importar la prioridad
    if (daysLeft <= 1) {
      final raised = p != TaskPriority.high;
      return TaskUrgency(
        task: task,
        level: UrgencyLevel.critical,
        deadline: deadline,
        // La hora manda; la prioridad solo desempata (hasta ~4 h)
        score: _criticalBase + hoursLeft - p.index * 2,
        dueLabel: label,
        reason: raised
            ? 'Subió a crítica: se entrega ${daysLeft == 0 ? 'hoy' : 'mañana'}'
            : null,
        raised: raised ? true : null,
      );
    }

    // 3. La prioridad acerca la fecha
    final feelsLikeDays = hoursLeft / 24 - _priorityBonusDays(p);
    final level = feelsLikeDays <= 3
        ? UrgencyLevel.high
        : feelsLikeDays <= 7
            ? UrgencyLevel.medium
            : UrgencyLevel.low;

    final own = _levelOf(p);
    String? reason;
    bool? raised;
    if (level.index < own.index) {
      reason = 'Subió: faltan pocos días';
      raised = true;
    } else if (level.index > own.index) {
      reason = 'Bajó: todavía hay tiempo';
      raised = false;
    }

    return TaskUrgency(
      task: task,
      level: level,
      deadline: deadline,
      score: feelsLikeDays * 24,
      dueLabel: label,
      reason: reason,
      raised: raised,
    );
  }

  /// Tareas pendientes ordenadas de más a menos urgente
  static List<TaskUrgency> rank(Iterable<Task> tasks, {DateTime? now}) {
    now ??= DateTime.now();
    return tasks
        .where((t) => !t.isCompleted)
        .map((t) => evaluate(t, now: now))
        .toList()
      ..sort((a, b) {
        final c = a.score.compareTo(b.score);
        return c != 0 ? c : a.task.createdAt.compareTo(b.task.createdAt);
      });
  }

  static const _weekdays = [
    'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'
  ];
  static const _months = [
    'ene', 'feb', 'mar', 'abr', 'may', 'jun',
    'jul', 'ago', 'sep', 'oct', 'nov', 'dic'
  ];

  static String _time(DateTime d) =>
      '${d.hour}:${d.minute.toString().padLeft(2, '0')}';

  /// Fecha de entrega en palabras, relativa a [now]
  static String dueLabel(DateTime due, {DateTime? now}) {
    now ??= DateTime.now();
    final deadline = deadlineOf(due);
    final withTime = hasTime(due);
    final days = _day(due).difference(_day(now)).inDays;
    final hoursLeft = deadline.difference(now).inMinutes / 60;

    if (hoursLeft < 0) {
      if (days == 0) return 'Venció hoy${withTime ? ' a las ${_time(due)}' : ''}';
      if (days == -1) return 'Venció ayer';
      return 'Venció hace ${-days} días';
    }
    if (days == 0) {
      if (withTime && hoursLeft < 1) return 'En ${(hoursLeft * 60).ceil()} min';
      if (withTime && hoursLeft < 6) return 'En ${hoursLeft.ceil()} h · ${_time(due)}';
      return withTime ? 'Hoy, ${_time(due)}' : 'Hoy';
    }
    if (days == 1) return withTime ? 'Mañana, ${_time(due)}' : 'Mañana';
    if (days < 7) {
      final day = 'El ${_weekdays[due.weekday - 1]}';
      return withTime ? '$day, ${_time(due)}' : day;
    }
    return 'En $days días · ${due.day} ${_months[due.month - 1]}';
  }
}
