import 'package:browninote/models/models.dart';
import 'package:browninote/services/task_urgency.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Jueves 8 de octubre de 2026, 10:00
  final now = DateTime(2026, 10, 8, 10);

  Task task(String title, {DateTime? due, TaskPriority p = TaskPriority.medium}) =>
      Task(
        id: title,
        notebookId: 'nb',
        title: title,
        dueDate: due,
        priority: p,
        createdAt: DateTime(2026, 1, 1),
      );

  List<String> order(List<Task> tasks) =>
      UrgencyEngine.rank(tasks, now: now).map((u) => u.task.title).toList();

  test('una tarea baja para mañana va antes que una alta para la otra semana', () {
    final result = order([
      task('alta lejana', due: DateTime(2026, 10, 15), p: TaskPriority.high),
      task('baja mañana', due: DateTime(2026, 10, 9), p: TaskPriority.low),
    ]);
    expect(result, ['baja mañana', 'alta lejana']);
  });

  test('las vencidas van primero, luego hoy, luego mañana', () {
    final result = order([
      task('mañana', due: DateTime(2026, 10, 9), p: TaskPriority.high),
      task('hoy', due: DateTime(2026, 10, 8), p: TaskPriority.low),
      task('vencida', due: DateTime(2026, 10, 6), p: TaskPriority.low),
    ]);
    expect(result, ['vencida', 'hoy', 'mañana']);
  });

  test('fuera de la zona crítica la prioridad adelanta la fecha', () {
    final result = order([
      task('baja en 3 días', due: DateTime(2026, 10, 11), p: TaskPriority.low),
      task('alta en 5 días', due: DateTime(2026, 10, 13), p: TaskPriority.high),
    ]);
    expect(result, ['alta en 5 días', 'baja en 3 días']);
  });

  test('entre tareas de hoy manda la hora de entrega', () {
    final result = order([
      task('alta 18:00', due: DateTime(2026, 10, 8, 18), p: TaskPriority.high),
      task('baja 12:00', due: DateTime(2026, 10, 8, 12), p: TaskPriority.low),
    ]);
    expect(result, ['baja 12:00', 'alta 18:00']);
  });

  test('sin fecha al final, por prioridad', () {
    final result = order([
      task('sin fecha baja', p: TaskPriority.low),
      task('sin fecha alta', p: TaskPriority.high),
      task('lejana', due: DateTime(2026, 12, 1), p: TaskPriority.low),
    ]);
    expect(result, ['lejana', 'sin fecha alta', 'sin fecha baja']);
  });

  test('niveles y motivos', () {
    final lowTomorrow = UrgencyEngine.evaluate(
        task('x', due: DateTime(2026, 10, 9), p: TaskPriority.low),
        now: now);
    expect(lowTomorrow.level, UrgencyLevel.critical);
    expect(lowTomorrow.reason, contains('mañana'));
    expect(lowTomorrow.raised, true);

    final highFar = UrgencyEngine.evaluate(
        task('y', due: DateTime(2026, 10, 30), p: TaskPriority.high),
        now: now);
    expect(highFar.level, UrgencyLevel.low);
    expect(highFar.raised, false);
  });

  test('una tarea de hoy sin hora no está vencida', () {
    final u = UrgencyEngine.evaluate(
        task('hoy', due: DateTime(2026, 10, 8)), now: now);
    expect(u.dueLabel, 'Hoy');
    expect(u.reason, isNot(contains('venció')));
  });

  test('etiquetas de fecha', () {
    expect(UrgencyEngine.dueLabel(DateTime(2026, 10, 8, 12), now: now),
        'En 2 h · 12:00');
    expect(UrgencyEngine.dueLabel(DateTime(2026, 10, 9), now: now), 'Mañana');
    expect(UrgencyEngine.dueLabel(DateTime(2026, 10, 10), now: now),
        'El sábado');
    expect(UrgencyEngine.dueLabel(DateTime(2026, 10, 7), now: now),
        'Venció ayer');
    expect(UrgencyEngine.dueLabel(DateTime(2026, 10, 20), now: now),
        'En 12 días · 20 oct');
  });
}
