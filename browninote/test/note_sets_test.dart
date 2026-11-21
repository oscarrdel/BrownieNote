import 'package:browninote/models/models.dart';
import 'package:browninote/providers/app_provider.dart';
import 'package:browninote/screens/home_screen.dart';
import 'package:browninote/screens/note_set_screen.dart';
import 'package:browninote/screens/notebook_screen.dart';
import 'package:browninote/theme/app_theme.dart';
import 'package:browninote/widgets/common_widgets.dart';
import 'package:browninote/widgets/note_tiles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _app(AppProvider provider, Widget home) => ChangeNotifierProvider.value(
      value: provider,
      child: MaterialApp(theme: AppTheme.light, home: home),
    );

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  final created = DateTime(2026, 10, 13);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('en teléfono las tareas próximas ocupan todo el ancho',
      (tester) async {
    _phone(tester);
    final provider = AppProvider();
    await provider.addNotebook('Física', '', Colors.indigo, '🔬');
    await tester.pumpWidget(_app(provider, const HomeScreen()));

    // 390 de ancho menos 20 de margen por lado
    final upcoming = find
        .ancestor(of: find.text('Tareas próximas'), matching: find.byType(BrownieTile))
        .first;
    expect(tester.getSize(upcoming).width, 390 - 40);
    // Los cuadernos siguen en dos columnas
    final notebook = find
        .ancestor(of: find.text('Física'), matching: find.byType(BrownieTile))
        .first;
    expect(tester.getSize(notebook).width, lessThan(200));
  });

  testWidgets('conjuntos y notas sueltas en el cuaderno, en teléfono',
      (tester) async {
    _phone(tester);
    final provider = AppProvider();
    await provider.addNotebook('Cálculo', 'Sem 3', Colors.teal, '📐');
    final nb = provider.notebooks.first;
    final set = (await provider.addNoteSet(nb.id, 'Parcial 1', '📁'))!;
    await provider.addNote(nb.id, 'Límites', [NoteBlock(text: 'epsilon delta')],
        setId: set.id);
    await provider.addNote(nb.id, 'Suelta', [NoteBlock(text: 'hola')],
        tags: ['examen', 'repaso', 'extra']);

    await tester.pumpWidget(_app(provider, NotebookScreen(notebookId: nb.id)));
    await tester.pumpAndSettle();

    // El cuaderno muestra el conjunto y la nota suelta, no la del conjunto
    expect(find.byType(NoteSetTile), findsOneWidget);
    expect(find.text('Suelta'), findsOneWidget);
    expect(find.text('Límites'), findsNothing);
    expect(find.text('1 nota'), findsOneWidget);

    await tester.tap(find.text('Parcial 1'));
    await tester.pumpAndSettle();
    expect(find.byType(NoteSetScreen), findsOneWidget);
    expect(find.text('Límites'), findsOneWidget);
    expect(find.text('Suelta'), findsNothing);

    // Borrar el conjunto deja sus notas sueltas
    await provider.deleteNoteSet(nb.id, set.id);
    await tester.pumpAndSettle();
    expect(provider.looseNotes(provider.notebookById(nb.id)!).length, 2);
    expect(provider.notes.length, 2);
  });

  test('mover una nota entre conjuntos y dejarla suelta', () async {
    final provider = AppProvider();
    await provider.addNotebook('Cálculo', '', Colors.teal, '📐');
    final nb = provider.notebooks.first;
    final set = (await provider.addNoteSet(nb.id, 'Parcial 1', '📁'))!;
    final note = await provider.addNote(nb.id, 'n', [NoteBlock(text: '')]);

    await provider.moveNote(note.id, set.id);
    expect(provider.notesInSet(nb.id, set.id).single.id, note.id);
    expect(provider.looseNotes(nb), isEmpty);

    await provider.moveNote(note.id, null);
    expect(provider.notesInSet(nb.id, set.id), isEmpty);
    expect(provider.looseNotes(nb).single.id, note.id);
  });

  test('los conjuntos del cuaderno sobreviven a JSON', () {
    final nb = Notebook(
      id: 'nb',
      name: 'Cálculo',
      subject: '',
      color: Colors.indigo,
      emoji: '📐',
      sets: [NoteSet(id: 's1', name: 'Parcial 1', emoji: '📁', createdAt: created)],
      createdAt: created,
    );
    final copy = Notebook.fromJson(nb.toJson());
    expect(copy.sets.single.name, 'Parcial 1');
    expect(copy.setById('s1')?.emoji, '📁');
    expect(copy.setById('nope'), isNull);
  });

  test('cuadernos y notas guardados antes de los conjuntos siguen cargando', () {
    final nb = Notebook.fromJson({
      'id': 'nb',
      'name': 'Viejo',
      'subject': '',
      'color': Colors.indigo.toARGB32(),
      'emoji': '📘',
      'createdAt': created.toIso8601String(),
    });
    expect(nb.sets, isEmpty);
    // La lista debe poder crecer (no ser const)
    nb.sets.add(NoteSet(id: 's', name: 'x', emoji: '📁', createdAt: created));

    final note = Note.fromJson({
      'id': 'n',
      'notebookId': 'nb',
      'title': 't',
      'content': '',
      'createdAt': created.toIso8601String(),
      'updatedAt': created.toIso8601String(),
    });
    expect(note.setId, isNull);
  });

  test('la nota recuerda su conjunto', () {
    final note = Note(
      id: 'n',
      notebookId: 'nb',
      setId: 's1',
      title: 't',
      content: '',
      blocks: const [],
      createdAt: created,
      updatedAt: created,
    );
    expect(Note.fromJson(note.toJson()).setId, 's1');
  });
}
