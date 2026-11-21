import 'dart:convert';
import 'dart:typed_data';

import 'package:uuid/uuid.dart';

/// Tipos de bloque del editor de notas
enum BlockType { paragraph, heading1, heading2, heading3, bullet, todo, quote, image }

/// Un bloque de contenido dentro de una nota
class NoteBlock {
  static const _uuid = Uuid();

  final String id;
  BlockType type;
  String text;

  /// Tamaño de fuente personalizado; null = tamaño por defecto del tipo
  double? fontSize;
  bool bold;
  bool italic;
  bool underline;

  /// Solo para listas de tareas
  bool checked;

  /// Solo para títulos: oculta todo lo que hay debajo hasta el siguiente
  /// título del mismo nivel o superior
  bool collapsed;

  /// Imagen guardada en disco (móvil/escritorio)
  String? imagePath;

  /// Imagen en base64 (web, donde no hay sistema de archivos)
  String? imageData;
  Uint8List? _imageBytes;

  /// Ancho de la imagen como fracción del ancho disponible (null = completo)
  double? widthFactor;

  /// Posición horizontal de la imagen: -1 izquierda, 0 centro, 1 derecha
  /// (null = izquierda)
  double? alignX;

  NoteBlock({
    String? id,
    this.type = BlockType.paragraph,
    this.text = '',
    this.fontSize,
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.checked = false,
    this.collapsed = false,
    this.imagePath,
    this.imageData,
    this.widthFactor,
    this.alignX,
  }) : id = id ?? _uuid.v4();

  bool get isHeading => headingLevel > 0;
  bool get isImage => type == BlockType.image;

  /// 1-3 para títulos, 0 para todo lo demás
  int get headingLevel => switch (type) {
        BlockType.heading1 => 1,
        BlockType.heading2 => 2,
        BlockType.heading3 => 3,
        _ => 0,
      };

  double get defaultFontSize => switch (type) {
        BlockType.heading1 => 28,
        BlockType.heading2 => 22,
        BlockType.heading3 => 18,
        _ => 15,
      };

  double get effectiveFontSize => fontSize ?? defaultFontSize;

  Uint8List? get imageBytes =>
      imageData == null ? null : (_imageBytes ??= base64Decode(imageData!));

  /// Reemplaza la imagen (por ejemplo, después de recortarla)
  void setImage({String? path, String? data}) {
    imagePath = path;
    imageData = data;
    _imageBytes = null;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'text': text,
        if (fontSize != null) 'fontSize': fontSize,
        if (bold) 'bold': true,
        if (italic) 'italic': true,
        if (underline) 'underline': true,
        if (checked) 'checked': true,
        if (collapsed) 'collapsed': true,
        if (imagePath != null) 'imagePath': imagePath,
        if (imageData != null) 'imageData': imageData,
        if (widthFactor != null) 'widthFactor': widthFactor,
        if (alignX != null) 'alignX': alignX,
      };

  factory NoteBlock.fromJson(Map<String, dynamic> json) => NoteBlock(
        id: json['id'],
        type: BlockType.values.asNameMap()[json['type']] ?? BlockType.paragraph,
        text: json['text'] ?? '',
        fontSize: (json['fontSize'] as num?)?.toDouble(),
        bold: json['bold'] ?? false,
        italic: json['italic'] ?? false,
        underline: json['underline'] ?? false,
        checked: json['checked'] ?? false,
        collapsed: json['collapsed'] ?? false,
        imagePath: json['imagePath'],
        imageData: json['imageData'],
        widthFactor: (json['widthFactor'] as num?)?.toDouble(),
        alignX: (json['alignX'] as num?)?.toDouble(),
      );

  NoteBlock copy() => NoteBlock.fromJson(toJson());

  /// Convierte el contenido de notas viejas (texto plano) a bloques
  static List<NoteBlock> fromPlainText(String content) {
    if (content.isEmpty) return [NoteBlock()];
    return content.split('\n').map((line) {
      for (final prefix in ['• ', '- ']) {
        if (line.startsWith(prefix)) {
          return NoteBlock(
              type: BlockType.bullet, text: line.substring(prefix.length));
        }
      }
      return NoteBlock(text: line);
    }).toList();
  }

  /// Texto plano para vistas previas y búsqueda
  static String toPlainText(List<NoteBlock> blocks) => blocks
      .where((b) => !b.isImage && b.text.trim().isNotEmpty)
      .map((b) => switch (b.type) {
            BlockType.bullet => '• ${b.text}',
            BlockType.todo => '${b.checked ? '☑' : '☐'} ${b.text}',
            _ => b.text,
          })
      .join('\n');
}
