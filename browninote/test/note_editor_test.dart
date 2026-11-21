import 'package:browninote/providers/app_provider.dart';
import 'package:browninote/screens/note_editor_screen.dart';
import 'package:browninote/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('atajos, enter y títulos plegables', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(ChangeNotifierProvider(
      create: (_) => AppProvider(),
      child: MaterialApp(
        theme: AppTheme.light,
        home: const NoteEditorScreen(notebookId: 'nb', notebookColor: Colors.indigo),
      ),
    ));

    Finder blockFields() => find.byType(TextField);
    // [título nota, bloque 1, etiqueta]
    expect(blockFields(), findsNWidgets(3));

    await tester.enterText(blockFields().at(1), '# ');
    await tester.pump();
    await tester.enterText(blockFields().at(1), 'Tema 1');
    await tester.pump();
    expect(find.byIcon(Icons.arrow_drop_down), findsWidgets);

    // Enter crea un párrafo nuevo
    await tester.enterText(blockFields().at(1), 'Tema 1\nhola');
    await tester.pump();
    await tester.pump();
    expect(blockFields(), findsNWidgets(4));
    expect(find.text('hola'), findsOneWidget);

    // Lista que continúa con Enter
    await tester.enterText(blockFields().at(2), 'hola\n- uno');
    await tester.pump();
    await tester.pump();
    expect(find.text('•'), findsOneWidget);
    expect(find.text('uno'), findsOneWidget);

    // Plegar el título oculta todo lo de abajo
    await tester.tap(find.byTooltip('Ocultar contenido'));
    await tester.pump();
    expect(find.text('hola'), findsNothing);
    expect(find.text('uno'), findsNothing);
    expect(find.byTooltip('Mostrar contenido (2 bloques)'), findsOneWidget);

    await tester.tap(find.byTooltip('Mostrar contenido (2 bloques)'));
    await tester.pump();
    expect(find.text('hola'), findsOneWidget);
  });
}
