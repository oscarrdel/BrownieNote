# Notas para desarrolladores

## Estructura

```
browninote/lib/
├── main.dart              Punto de entrada. Crea AppProvider y carga los datos locales.
├── config/features.dart   Interruptores de funciones (adjuntos e imágenes en notas).
├── models/                Cuadernos, conjuntos, notas, tareas y bloques de nota.
├── providers/             AppProvider: estado de la app y persistencia local.
├── screens/               Pantallas completas (inicio, cuaderno, editor, tareas, calendario).
├── services/              Lógica sin UI: guardado de archivos y urgencia de tareas.
├── theme/                 Colores y tipografía (claro y oscuro).
└── widgets/               Componentes reutilizables.
```

## Datos

- Todo se guarda en `SharedPreferences` como JSON, en tres claves: `notebooks`, `notes` y `tasks`.
- `AppProvider._writeLocal()` escribe las tres listas después de cada cambio. Cada método que modifica datos llama a `_save()`.
- Los archivos adjuntos y las imágenes se guardan con `FileStorage` (`services/file_storage.dart`). En la web usan el almacenamiento del navegador, que tiene un límite de 2 MB por archivo.
- Si los datos guardados están dañados, `loadData()` deja la app vacía en lugar de fallar al abrir.

## Modelo de notas

- Una nota es una lista de `NoteBlock`. Cada bloque tiene tipo (texto, lista, título, imagen, etc.).
- `Note.content` es texto plano derivado de los bloques, para vistas previas y búsqueda. Se recalcula al guardar.
- Un conjunto (`NoteSet`) vive dentro de su cuaderno. Si se borra un conjunto, sus notas quedan sueltas en el cuaderno.

## Flags

`config/features.dart` tiene dos constantes booleanas: `taskAttachmentsEnabled` y `noteImagesEnabled`. Ponerlas en `false` oculta esas funciones en todas las compilaciones.

## Comandos

```
cd browninote
flutter pub get
flutter analyze
flutter test
flutter run
flutter build windows --release
flutter build apk --release
```

## Pruebas

- `test/note_editor_test.dart`: atajos del editor y títulos plegables.
- `test/note_sets_test.dart`: conjuntos, mover notas y persistencia en JSON.
- `test/task_detail_and_editor_test.dart`: vista de tareas, arrastre y tamaño de imágenes.
- `test/task_urgency_test.dart`: orden y niveles de urgencia de las tareas.

## Versiones

- La versión de escritorio para Windows se publica como Release en GitHub (`v1.0.0`).
- La rama `web` contiene solo la página estática y el archivo `CNAME`. No comparte historial con `main`.
