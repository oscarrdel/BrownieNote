import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import '../providers/app_provider.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'task_detail_screen.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _focusedDay;
  late DateTime _selectedDay;

  @override
  void initState() {
    super.initState();
    _focusedDay = DateTime.now();
    _selectedDay = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final colors = BrownieColors.of(context);

    final selectedTasks = provider.tasksForDay(_selectedDay);
    final selectedNotes = provider.notesForDay(_selectedDay);
    final daysWithEvents = provider.daysWithEvents;

    return Scaffold(
      backgroundColor: colors.bg,
      body: Column(
        children: [
          // ─── Header ────────────────────────────────────────────────────────
          Container(
            padding: EdgeInsets.fromLTRB(
                8, MediaQuery.paddingOf(context).top + 16, 20, 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colors.primary.withAlpha(180),
                  colors.secondary.withAlpha(120),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    BackButton(color: Colors.white),
                    SizedBox(width: 4),
                    Text(
                      '📅 Calendario',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Text(
                    '${provider.pendingTasksCount} tareas pendientes · ${provider.overdueTasksCount > 0 ? "⚠️ ${provider.overdueTasksCount} vencidas" : "Todo al día ✓"}',
                    style: TextStyle(
                      color: Colors.white.withAlpha(200),
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ─── Calendario ────────────────────────────────────────────────────
          Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: colors.divider),
              boxShadow: [
                BoxShadow(
                  color: colors.primary.withAlpha(15),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                )
              ],
            ),
            child: TableCalendar(
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: _focusedDay,
              selectedDayPredicate: (d) => isSameDay(d, _selectedDay),
              eventLoader: (day) {
                final normalized =
                    DateTime(day.year, day.month, day.day);
                return daysWithEvents.contains(normalized) ? [1] : [];
              },
              onDaySelected: (selected, focused) {
                setState(() {
                  _selectedDay = selected;
                  _focusedDay = focused;
                });
              },
              calendarStyle: CalendarStyle(
                todayDecoration: BoxDecoration(
                  color: colors.primary.withAlpha(100),
                  shape: BoxShape.circle,
                ),
                selectedDecoration: BoxDecoration(
                  color: colors.primary,
                  shape: BoxShape.circle,
                ),
                markerDecoration: BoxDecoration(
                  color: colors.secondary,
                  shape: BoxShape.circle,
                ),
                weekendTextStyle: TextStyle(color: colors.text),
                defaultTextStyle: TextStyle(color: colors.text),
                outsideTextStyle: TextStyle(color: colors.subtext),
                todayTextStyle: TextStyle(color: colors.text),
                selectedTextStyle: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700),
              ),
              headerStyle: HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                titleTextStyle: TextStyle(
                  color: colors.text,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
                leftChevronIcon:
                    Icon(Icons.chevron_left, color: colors.primary),
                rightChevronIcon:
                    Icon(Icons.chevron_right, color: colors.primary),
              ),
              daysOfWeekStyle: DaysOfWeekStyle(
                weekdayStyle: TextStyle(
                  color: colors.subtext,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
                weekendStyle: TextStyle(
                  color: colors.subtext,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ),

          // ─── Eventos del día seleccionado ──────────────────────────────────
          Expanded(
            child: _DayEventsPanel(
              day: _selectedDay,
              tasks: selectedTasks,
              notes: selectedNotes,
              notebooks: provider.notebooks,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Panel de eventos del día ────────────────────────────────────────────────

class _DayEventsPanel extends StatelessWidget {
  final DateTime day;
  final List<Task> tasks;
  final List<Note> notes;
  final List<Notebook> notebooks;

  const _DayEventsPanel({
    required this.day,
    required this.tasks,
    required this.notes,
    required this.notebooks,
  });

  Notebook? _notebookOf(String id) {
    try {
      return notebooks.firstWhere((n) => n.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = BrownieColors.of(context);
    final now = DateTime.now();
    final isToday = day.year == now.year &&
        day.month == now.month &&
        day.day == now.day;

    final dayLabel = isToday
        ? 'Hoy'
        : '${day.day}/${day.month}/${day.year}';

    if (tasks.isEmpty && notes.isEmpty) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Text(
                  dayLabel,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: colors.primary,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('🌿', style: const TextStyle(fontSize: 40)),
                  const SizedBox(height: 10),
                  Text('Sin actividad este día',
                      style: TextStyle(
                          color: colors.subtext,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
          child: Text(
            dayLabel,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: colors.primary,
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              if (tasks.isNotEmpty) ...[
                _PanelSection(label: '✅ Tareas (${tasks.length})'),
                ...tasks.map((t) {
                  final nb = _notebookOf(t.notebookId);
                  return _CalendarTaskItem(task: t, notebook: nb);
                }),
              ],
              if (notes.isNotEmpty) ...[
                const SizedBox(height: 8),
                _PanelSection(label: '📝 Notas (${notes.length})'),
                ...notes.map((n) {
                  final nb = _notebookOf(n.notebookId);
                  return _CalendarNoteItem(note: n, notebook: nb);
                }),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _PanelSection extends StatelessWidget {
  final String label;
  const _PanelSection({required this.label});

  @override
  Widget build(BuildContext context) {
    final colors = BrownieColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: colors.subtext,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _CalendarTaskItem extends StatelessWidget {
  final Task task;
  final Notebook? notebook;

  const _CalendarTaskItem({required this.task, this.notebook});

  @override
  Widget build(BuildContext context) {
    final colors = BrownieColors.of(context);
    final color = notebook?.color ?? colors.primary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: BrownieCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => TaskDetailScreen(taskId: task.id)),
        ),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 36,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
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
                      fontSize: 13,
                      color: task.isCompleted
                          ? colors.subtext
                          : colors.text,
                      decoration: task.isCompleted
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  if (notebook != null)
                    Text(
                      '${notebook!.emoji} ${notebook!.name}',
                      style: TextStyle(
                          fontSize: 11, color: colors.subtext),
                    ),
                ],
              ),
            ),
            if (task.isCompleted)
              Icon(Icons.check_circle, color: color, size: 18)
            else if (task.isOverdue)
              const Icon(Icons.warning_amber_rounded,
                  color: Color(0xFFE5524E), size: 18),
          ],
        ),
      ),
    );
  }
}

class _CalendarNoteItem extends StatelessWidget {
  final Note note;
  final Notebook? notebook;

  const _CalendarNoteItem({required this.note, this.notebook});

  @override
  Widget build(BuildContext context) {
    final colors = BrownieColors.of(context);
    final color = notebook?.color ?? colors.primary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: BrownieCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 36,
              decoration: BoxDecoration(
                color: color.withAlpha(160),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    note.title.isEmpty ? 'Sin título' : note.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: colors.text,
                    ),
                  ),
                  if (notebook != null)
                    Text(
                      '${notebook!.emoji} ${notebook!.name}',
                      style: TextStyle(
                          fontSize: 11, color: colors.subtext),
                    ),
                ],
              ),
            ),
            Icon(Icons.article_outlined, color: color, size: 18),
          ],
        ),
      ),
    );
  }
}
