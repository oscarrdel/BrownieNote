import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Referencia a un archivo guardado por la app: en disco (móvil/escritorio)
/// o en base64 (web, donde no hay sistema de archivos).
typedef StoredRef = ({String? path, String? data});

/// Un archivo elegido por el usuario, todavía sin guardar
typedef ChosenFile = ({String name, Uint8List bytes});

const imageExtensions = {'png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp'};

String extensionOf(String name) =>
    name.contains('.') ? name.split('.').last.toLowerCase() : '';

bool isImageName(String name) => imageExtensions.contains(extensionOf(name));

class FileStorage {
  static final _picker = ImagePicker();

  /// La cámara solo está disponible en móvil
  static bool get canUseCamera =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Abrir archivos con otra app solo es posible fuera de la web
  static bool get canOpenExternally => !kIsWeb;

  // ─── Guardar / leer ───────────────────────────────────────────────────────

  static Future<StoredRef> save(Uint8List bytes, String name,
      {String folder = 'files'}) async {
    if (kIsWeb) return (path: null, data: base64Encode(bytes));

    final dir = await getApplicationSupportDirectory();
    final target = Directory('${dir.path}/$folder/${const Uuid().v4()}');
    await target.create(recursive: true);
    // Se conserva el nombre original para que al abrirlo se vea bien
    final safeName = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final file = File('${target.path}/$safeName');
    await file.writeAsBytes(bytes);
    return (path: file.path, data: null);
  }

  static Future<Uint8List?> read(StoredRef ref) async {
    if (ref.data != null) return base64Decode(ref.data!);
    if (ref.path != null && !kIsWeb) {
      final file = File(ref.path!);
      if (await file.exists()) return file.readAsBytes();
    }
    return null;
  }

  /// Abre el archivo con la app predeterminada del sistema
  static Future<String?> open(StoredRef ref) async {
    if (ref.path == null || kIsWeb) return 'No disponible en la versión web';
    final result = await OpenFilex.open(ref.path!);
    return result.type == ResultType.done ? null : result.message;
  }

  // ─── Elegir archivos ──────────────────────────────────────────────────────

  /// Imagen de galería o cámara, reducida para no ocupar demasiado
  static Future<ChosenFile?> pickImage(ImageSource source) async {
    final file = await _picker.pickImage(
      source: source,
      maxWidth: 2000,
      maxHeight: 2000,
      imageQuality: 80,
    );
    if (file == null) return null;
    return (name: file.name, bytes: await file.readAsBytes());
  }

  /// Cualquier tipo de archivo (documentos, PDFs, imágenes...)
  static Future<List<ChosenFile>> pickFiles() async {
    final files = await FilePicker.pickFiles(dialogTitle: 'Agregar archivos');
    return [
      for (final f in files) (name: f.name, bytes: await f.readAsBytes()),
    ];
  }

  /// Imagen del portapapeles: una imagen copiada o un archivo de imagen
  /// copiado desde el explorador. Devuelve null si no hay ninguna.
  static Future<ChosenFile?> pasteImage() async {
    final bytes = await Pasteboard.image;
    if (bytes != null && bytes.isNotEmpty) {
      return (name: 'imagen.png', bytes: bytes);
    }
    if (kIsWeb) return null;
    for (final path in await Pasteboard.files()) {
      if (isImageName(path)) {
        final name = path.split(RegExp(r'[\\/]')).last;
        return (name: name, bytes: await File(path).readAsBytes());
      }
    }
    return null;
  }
}

/// Muestra una imagen guardada, venga de disco o de base64
class StoredImage extends StatelessWidget {
  final StoredRef ref;
  final Uint8List? bytes;
  final BoxFit fit;

  const StoredImage({
    super.key,
    required this.ref,
    this.bytes,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    Widget broken(BuildContext context, Object error, StackTrace? stack) =>
        Container(
          height: 120,
          alignment: Alignment.center,
          color: Colors.black12,
          child: const Icon(Icons.broken_image_outlined, size: 40),
        );

    final memory = bytes ?? (ref.data != null ? base64Decode(ref.data!) : null);
    if (memory != null) {
      return Image.memory(memory, fit: fit, errorBuilder: broken, gaplessPlayback: true);
    }
    if (ref.path != null && !kIsWeb) {
      return Image.file(File(ref.path!), fit: fit, errorBuilder: broken);
    }
    return broken(context, 'missing', null);
  }
}
