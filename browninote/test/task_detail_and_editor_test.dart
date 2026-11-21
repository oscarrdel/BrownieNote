import 'dart:convert';

import 'package:browninote/models/models.dart';
import 'package:browninote/providers/app_provider.dart';
import 'package:browninote/screens/note_editor_screen.dart';
import 'package:browninote/screens/task_detail_screen.dart';
import 'package:browninote/theme/app_theme.dart';
import 'package:browninote/widgets/note_image_block.dart';
import 'package:browninote/widgets/task_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// PNG de 1x1 píxel
final _pixel = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==');

Widget _app(AppProvider provider, Widget home) => ChangeNotifierProvider.value(
      value: provider,
      child: MaterialApp(theme: AppTheme.light, home: home),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('tocar una tarea abre la vista de lectura, no el formulario',
      (tester) async {
    final provider = AppProvider();
    await provider.addNotebook('Física', 'Bloque 2', Colors.indigo, '🔬');
    final nb = provider.notebooks.first;
    final task = await provider.addTask(nb.id, 'Reporte de laboratorio',
        description: 'Incluir gráficas y conclusiones',
        dueDate: DateTime.now().add(const Duration(days: 1)),
        attachments: [
          Attachment(
            id: 'a1',
            name: 'rubrica.pdf',
            data: base64Encode([1, 2, 3]),
            size: 3,
            addedAt: DateTime.now(),
          ),
        ]);

    await tester.pumpWidget(_app(
        provider, Scaffold(body: TaskTile(task: task, notebook: nb))));
    await tester.tap(find.text('Reporte de laboratorio'));
    await tester.pumpAndSettle();

    expect(find.byType(TaskDetailScreen), findsOneWidget);
    expect(find.text('Incluir gráficas y conclusiones'), findsOneWidget);
    expect(find.text('rubrica.pdf'), findsOneWidget);
    expect(find.text('Editar'), findsOneWidget);
    // No es el formulario: no hay campos editables
    expect(find.byType(TextField), findsNothing);

    await tester.tap(find.text('Editar'));
    await tester.pumpAndSettle();
    expect(find.text('Editar tarea'), findsOneWidget);
  });

  testWidgets('arrastrar un bloque lo mueve de lugar', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final provider = AppProvider();
    final note = Note(
      id: 'n',
      notebookId: 'nb',
      title: 'Apuntes',
      content: '',
      blocks: [
        NoteBlock(text: 'uno'),
        NoteBlock(text: 'dos'),
        NoteBlock(text: 'tres'),
      ],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await tester.pumpWidget(_app(
        provider,
        NoteEditorScreen(
            notebookId: 'nb', notebookColor: Colors.indigo, existingNote: note)));

    double y(String text) => tester.getCenter(find.text(text)).dy;
    expect(y('uno') < y('dos'), isTrue);

    // Arrastra la manija del primer bloque hasta debajo del tercero
    final handle = find.byIcon(Icons.drag_indicator).first;
    final gesture = await tester.startGesture(tester.getCenter(handle));
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.moveBy(const Offset(0, 40));
    await tester.pump();
    await gesture.moveTo(Offset(tester.getCenter(handle).dx, y('tres') + 30));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(y('dos') < y('tres'), isTrue);
    expect(y('tres') < y('uno'), isTrue);
  });

  testWidgets('jalar el borde de una imagen cambia su tamaño', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final image = NoteBlock(
        type: BlockType.image, imageData: base64Encode(_pixel));
    final note = Note(
      id: 'n',
      notebookId: 'nb',
      title: 'Con imagen',
      content: '',
      blocks: [image, NoteBlock(text: 'texto')],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await tester.pumpWidget(_app(
        AppProvider(),
        NoteEditorScreen(
            notebookId: 'nb', notebookColor: Colors.indigo, existingNote: note)));

    // Las imágenes se decodifican de forma asíncrona
    await tester.runAsync(() => precacheImage(
        MemoryImage(image.imageBytes!), tester.element(find.byType(NoteImageBlock))));
    await tester.pumpAndSettle();

    final block = find.byType(NoteImageBlock);
    double width() => tester
        .getSize(find.descendant(of: block, matching: find.byType(SizedBox)).first)
        .width;
    final before = width();
    final handles = find.descendant(
        of: block,
        matching: find.byWidgetPredicate((w) =>
            w is MouseRegion &&
            w.cursor.toString().contains('resize')));

    // Sin doble clic no hay puntos para jalar
    expect(handles, findsNothing);

    // Doble clic: aparecen los 8 puntos (4 esquinas + 4 lados)
    final center = tester.getCenter(block);
    await tester.tapAt(center);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(center);
    await tester.pumpAndSettle();
    expect(handles, findsNWidgets(8));

    // Jalar la esquina superior derecha hacia adentro la achica
    final corner = tester.getRect(find.descendant(
        of: block, matching: find.byType(ClipRRect)).first).topRight;
    await tester.dragFrom(corner + const Offset(-2, 2), const Offset(-200, 20));
    await tester.pumpAndSettle();
    expect(width(), lessThan(before - 150));
    expect(find.text('Guardar'), findsOneWidget); // marcó cambios

    // Esc sale del modo de tamaño
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(handles, findsNothing);
  });

  testWidgets('la imagen seleccionada se arrastra a los lados y entre bloques',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final image = NoteBlock(
        type: BlockType.image,
        imageData: base64Encode(_pixel),
        widthFactor: 0.3,
        alignX: -1);
    final note = Note(
      id: 'n',
      notebookId: 'nb',
      title: 'Mover',
      content: '',
      blocks: [image, NoteBlock(text: 'debajo')],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await tester.pumpWidget(_app(
        AppProvider(),
        NoteEditorScreen(
            notebookId: 'nb', notebookColor: Colors.indigo, existingNote: note)));
    await tester.runAsync(() => precacheImage(MemoryImage(image.imageBytes!),
        tester.element(find.byType(NoteImageBlock))));
    await tester.pumpAndSettle();

    Rect imageRect() => tester.getRect(find
        .descendant(
            of: find.byType(NoteImageBlock), matching: find.byType(ClipRRect))
        .first);

    // Seleccionar (un clic; se espera a que no sea doble clic)
    await tester.tapAt(imageRect().center);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    // Arrastrar a la derecha
    final leftBefore = imageRect().left;
    await tester.dragFrom(imageRect().center, const Offset(300, 0));
    await tester.pumpAndSettle();
    expect(imageRect().left, greaterThan(leftBefore + 250));

    // Arrastrar hacia abajo, más allá del texto: queda debajo de él
    expect(imageRect().top < tester.getRect(find.text('debajo')).top, isTrue);
    final textBottom = tester.getRect(find.text('debajo')).bottom;
    final drop = textBottom + imageRect().height / 2 + 20 - imageRect().center.dy;
    await tester.dragFrom(imageRect().center, Offset(0, drop));
    await tester.pumpAndSettle();
    expect(imageRect().top > tester.getRect(find.text('debajo')).top, isTrue);
  });
}
