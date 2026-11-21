import '../config/features.dart';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/models.dart';
import '../services/file_storage.dart';
import '../widgets/note_image_block.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class NoteEditorScreen extends StatefulWidget {
  final String notebookId;
  final Color notebookColor;
  final Note? existingNote;

  /// Conjunto donde se crea la nota nueva; null = suelta en el cuaderno
  final String? setId;

  const NoteEditorScreen({
    super.key,
    required this.notebookId,
    required this.notebookColor,
    this.existingNote,
    this.setId,
  });

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  static const _fontSizes = <double>[10, 12, 14, 15, 16, 18, 20, 22, 24, 28, 32, 40, 48];

  /// Atajos de teclado: se escriben al inicio de un párrafo
  static const _shortcuts = <String, BlockType>{
    '# ': BlockType.heading1,
    '## ': BlockType.heading2,
    '### ': BlockType.heading3,
    '- ': BlockType.bullet,
    '* ': BlockType.bullet,
    '[] ': BlockType.todo,
    '> ': BlockType.quote,
  };

  late TextEditingController _titleCtrl;
  late TextEditingController _tagCtrl;
  late List<String> _tags;
  late List<NoteBlock> _blocks;
  final _controllers = <String, TextEditingController>{};
  final _focusNodes = <String, FocusNode>{};
  String? _activeId;
  String? _hoveredId;

  /// Imagen en modo de tamaño (doble clic): muestra los puntos para jalar
  String? _resizingId;
  final _rowKeys = <String, GlobalKey>{};
  bool _hasChanges = false;

  /// Foco del editor completo: recibe Ctrl+V y Supr cuando hay una imagen
  /// seleccionada (las imágenes no son campos de texto)
  late final FocusNode _editorFocus =
      FocusNode(debugLabel: 'editor', onKeyEvent: _onEditorKey);

  @override
  void initState() {
    super.initState();
    final note = widget.existingNote;
    _titleCtrl = TextEditingController(text: note?.title ?? '');
    _tagCtrl = TextEditingController();
    _tags = List.from(note?.tags ?? []);
    // Copias, para que cancelar no modifique la nota original
    _blocks = note?.blocks.map((b) => b.copy()).toList() ?? [];
    if (_blocks.isEmpty) _blocks.add(NoteBlock());

    _titleCtrl.addListener(_markChanged);
  }

  void _markChanged() {
    if (!_hasChanges) setState(() => _hasChanges = true);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _tagCtrl.dispose();
    _editorFocus.dispose();
    for (final c in _controllers.values) {
      c.dispose();
    }
    for (final f in _focusNodes.values) {
      f.dispose();
    }
    super.dispose();
  }

  // ─── Controladores por bloque ─────────────────────────────────────────────

  TextEditingController _ctrlFor(NoteBlock block) =>
      _controllers.putIfAbsent(block.id, () {
        final c = TextEditingController(text: block.text);
        c.addListener(() => _onTextChanged(block));
        return c;
      });

  FocusNode _focusFor(NoteBlock block) => _focusNodes.putIfAbsent(block.id, () {
        final f = FocusNode(onKeyEvent: (_, event) => _onKey(block, event));
        f.addListener(() {
          if (f.hasFocus && _activeId != block.id) {
            setState(() => _activeId = block.id);
          }
        });
        return f;
      });

  void _setText(NoteBlock block, String text, {int? cursor}) {
    block.text = text;
    _ctrlFor(block).value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: cursor ?? text.length),
    );
  }

  void _focusBlock(NoteBlock block, {int? cursor}) {
    if (_resizingId != block.id) _resizingId = null;
    setState(() => _activeId = block.id);
    if (block.isImage) {
      // El editor recibe el foco para que Supr/Ctrl+V funcionen con la imagen
      _editorFocus.requestFocus();
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focusFor(block).requestFocus();
      final ctrl = _ctrlFor(block);
      ctrl.selection = TextSelection.collapsed(
          offset: (cursor ?? ctrl.text.length).clamp(0, ctrl.text.length));
    });
  }

  void _removeBlock(NoteBlock block) {
    _blocks.remove(block);
    final ctrl = _controllers.remove(block.id);
    final focus = _focusNodes.remove(block.id);
    _rowKeys.remove(block.id);
    // Se liberan después del frame, el widget todavía los usa
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ctrl?.dispose();
      focus?.dispose();
    });
    if (_blocks.isEmpty) _blocks.add(NoteBlock());
  }

  // ─── Estructura: títulos plegables ────────────────────────────────────────

  /// Índices de los bloques visibles (los que no están dentro de un título plegado)
  List<int> _visibleIndices() {
    final out = <int>[];
    int? hiddenUnderLevel;
    for (var i = 0; i < _blocks.length; i++) {
      final b = _blocks[i];
      if (hiddenUnderLevel != null) {
        if (b.isHeading && b.headingLevel <= hiddenUnderLevel) {
          hiddenUnderLevel = null;
        } else {
          continue;
        }
      }
      out.add(i);
      if (b.isHeading && b.collapsed) hiddenUnderLevel = b.headingLevel;
    }
    return out;
  }

  /// Índice donde termina la sección de un título (exclusivo)
  int _sectionEnd(int headingIdx) {
    final level = _blocks[headingIdx].headingLevel;
    var j = headingIdx + 1;
    while (j < _blocks.length &&
        !(_blocks[j].isHeading && _blocks[j].headingLevel <= level)) {
      j++;
    }
    return j;
  }

  int _hiddenCount(int headingIdx) => _sectionEnd(headingIdx) - headingIdx - 1;

  void _toggleCollapse(NoteBlock block) {
    setState(() => block.collapsed = !block.collapsed);
    _markChanged();
  }

  // ─── Escritura ────────────────────────────────────────────────────────────

  void _onTextChanged(NoteBlock block) {
    final text = _ctrlFor(block).text;
    if (text == block.text) return; // solo cambió la selección

    if (text.contains('\n')) {
      _splitBlock(block, text);
      _markChanged();
      return;
    }

    final shortcut = _matchShortcut(block, text);
    if (shortcut != null) {
      setState(() => block.type = shortcut.$1);
      _setText(block, shortcut.$2, cursor: 0);
      _markChanged();
      return;
    }

    block.text = text;
    _markChanged();
  }

  /// Si un párrafo empieza con un atajo, devuelve el tipo nuevo y el texto restante
  (BlockType, String)? _matchShortcut(NoteBlock block, String text) {
    if (block.type != BlockType.paragraph) return null;
    for (final entry in _shortcuts.entries) {
      if (text.startsWith(entry.key)) {
        return (entry.value, text.substring(entry.key.length));
      }
    }
    return null;
  }

  /// Enter (o pegar varias líneas) crea bloques nuevos
  void _splitBlock(NoteBlock block, String text) {
    final lines = text.split('\n');
    final isList = block.type == BlockType.bullet ||
        block.type == BlockType.todo ||
        block.type == BlockType.quote;

    // Enter en un elemento de lista vacío: sale de la lista
    if (isList && lines.length == 2 && lines.every((l) => l.isEmpty)) {
      setState(() => block.type = BlockType.paragraph);
      _setText(block, '');
      return;
    }

    _setText(block, lines.first);
    final idx = _blocks.indexOf(block);
    final insertAt =
        block.isHeading && block.collapsed ? _sectionEnd(idx) : idx + 1;
    final continues = block.type == BlockType.bullet || block.type == BlockType.todo;
    final newBlocks = lines.skip(1).map((line) => NoteBlock(
          type: continues ? block.type : BlockType.paragraph,
          text: line,
          fontSize: continues ? block.fontSize : null,
          bold: continues && block.bold,
          italic: continues && block.italic,
          underline: continues && block.underline,
        )).toList();
    // Texto pegado con "# ", "- ", etc. también se convierte
    for (final b in newBlocks) {
      final shortcut = _matchShortcut(b, b.text);
      if (shortcut != null) {
        b.type = shortcut.$1;
        b.text = shortcut.$2;
      }
    }

    setState(() => _blocks.insertAll(insertAt, newBlocks));
    _focusBlock(newBlocks.last, cursor: lines.length == 2 ? 0 : null);
  }

  /// Recibe las teclas de todo el editor (también las que suben desde los
  /// bloques de texto, si ellos no las usaron)
  KeyEventResult _onEditorKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final keyboard = HardwareKeyboard.instance;
    final ctrl = keyboard.isControlPressed || keyboard.isMetaPressed;

    if (ctrl && event.logicalKey == LogicalKeyboardKey.keyV) {
      _pasteImage(quiet: true);
      // Se deja pasar para que el texto se pegue de forma normal
      return KeyEventResult.ignored;
    }

    final active = _active;
    if (event.logicalKey == LogicalKeyboardKey.escape && _resizingId != null) {
      setState(() => _resizingId = null);
      return KeyEventResult.handled;
    }
    final deleteKey = event.logicalKey == LogicalKeyboardKey.delete ||
        event.logicalKey == LogicalKeyboardKey.backspace;
    if (deleteKey && node.hasPrimaryFocus && active != null && active.isImage) {
      _deleteActive();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _onKey(NoteBlock block, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey != LogicalKeyboardKey.backspace) {
      return KeyEventResult.ignored;
    }
    final sel = _ctrlFor(block).selection;
    if (!sel.isCollapsed || sel.baseOffset != 0) return KeyEventResult.ignored;

    // Borrar al inicio de un título/lista lo convierte en texto normal
    if (block.type != BlockType.paragraph) {
      setState(() {
        block.type = BlockType.paragraph;
        block.fontSize = null;
        block.collapsed = false;
      });
      _markChanged();
      return KeyEventResult.handled;
    }

    // Unir con el bloque visible anterior
    final visible = _visibleIndices();
    final pos = visible.indexOf(_blocks.indexOf(block));
    if (pos <= 0) return KeyEventResult.ignored;
    final prev = _blocks[visible[pos - 1]];

    if (prev.isImage) {
      if (block.text.isEmpty) {
        setState(() => _removeBlock(block));
        _focusBlock(prev);
      }
      return KeyEventResult.handled;
    }

    final joinAt = prev.text.length;
    _setText(prev, prev.text + block.text);
    setState(() => _removeBlock(block));
    _focusBlock(prev, cursor: joinAt);
    _markChanged();
    return KeyEventResult.handled;
  }

  // ─── Acciones de la barra de herramientas ─────────────────────────────────

  NoteBlock? get _active {
    for (final b in _blocks) {
      if (b.id == _activeId) return b;
    }
    return null;
  }

  void _edit(void Function(NoteBlock b) change, {bool refocus = true}) {
    final block = _active;
    if (block == null) return;
    setState(() => change(block));
    _markChanged();
    if (refocus && !block.isImage) _focusBlock(block, cursor: _ctrlFor(block).selection.baseOffset);
  }

  void _setType(BlockType type) => _edit((b) {
        b.type = type;
        b.fontSize = null;
        if (type != BlockType.todo) b.checked = false;
        if (!b.isHeading) b.collapsed = false;
      });

  void _changeFontSize(int direction) => _edit((b) {
        final current = b.effectiveFontSize;
        final next = direction > 0
            ? _fontSizes.firstWhere((s) => s > current, orElse: () => _fontSizes.last)
            : _fontSizes.lastWhere((s) => s < current, orElse: () => _fontSizes.first);
        b.fontSize = next == b.defaultFontSize ? null : next;
      });

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _insertImage(ImageSource source) =>
      _insertImageFrom(() => FileStorage.pickImage(source));

  /// Pega una imagen del portapapeles. Con [quiet] no avisa si no hay ninguna
  /// (al presionar Ctrl+V normalmente se está pegando texto).
  Future<void> _pasteImage({bool quiet = false}) => _insertImageFrom(() async {
        if (quiet) {
          // Si hay texto copiado, Ctrl+V pega el texto y no una imagen
          final text = await Clipboard.getData(Clipboard.kTextPlain);
          if (text?.text?.isNotEmpty ?? false) return null;
        }
        final image = await FileStorage.pasteImage();
        if (image == null && !quiet) {
          _snack('No hay ninguna imagen en el portapapeles');
        }
        return image;
      });

  Future<void> _insertImageFrom(Future<ChosenFile?> Function() source) async {
    if (!noteImagesEnabled) return;
    final NoteBlock image;
    try {
      final file = await source();
      if (file == null) return;
      final ref =
          await FileStorage.save(file.bytes, file.name, folder: 'note_images');
      image = NoteBlock(
        type: BlockType.image,
        imagePath: ref.path,
        imageData: ref.data,
        widthFactor: await _naturalWidthFactor(file.bytes),
        alignX: -1,
      );
    } catch (e) {
      _snack('No se pudo agregar la imagen: $e');
      return;
    }
    if (!mounted) return;

    final active = _active;
    var insertAt = active == null ? _blocks.length : _blocks.indexOf(active) + 1;
    if (active != null && active.isHeading && active.collapsed) {
      insertAt = _sectionEnd(_blocks.indexOf(active));
    }
    setState(() {
      _blocks.insert(insertAt, image);
      // Siempre debe quedar un lugar para seguir escribiendo
      if (insertAt == _blocks.length - 1) _blocks.add(NoteBlock());
    });
    _markChanged();
    _focusBlock(_blocks[insertAt + 1]);
  }

  /// Ancho inicial de una imagen nueva: su tamaño real en pantalla (como se
  /// veía donde se copió), sin pasar del 70% del ancho de la nota
  Future<double?> _naturalWidthFactor(Uint8List bytes) async {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    // Ancho del área de texto: pantalla menos márgenes y la manija ⋮⋮
    final contentWidth = MediaQuery.sizeOf(context).width - 90;
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final pixels = frame.image.width;
      frame.image.dispose();
      codec.dispose();
      return (pixels / dpr / contentWidth).clamp(0.1, 0.7);
    } catch (_) {
      return 0.5;
    }
  }

  /// Mueve [moved] (con su sección, si es un título plegado) delante de
  /// [before]; null = al final
  void _moveBefore(NoteBlock moved, NoteBlock? before) {
    if (before == moved) return;
    final start = _blocks.indexOf(moved);
    final end =
        moved.isHeading && moved.collapsed ? _sectionEnd(start) : start + 1;
    setState(() {
      final unit = _blocks.sublist(start, end);
      _blocks.removeRange(start, end);
      final insertAt =
          before == null ? _blocks.length : _blocks.indexOf(before);
      _blocks.insertAll(insertAt, unit);
      if (_blocks.last.isImage) _blocks.add(NoteBlock());
    });
    _markChanged();
  }

  /// Se soltó una imagen arrastrada: queda delante del primer bloque cuyo
  /// centro está debajo de donde se soltó
  void _dropBlock(NoteBlock moved, double dropY) {
    NoteBlock? before;
    for (final i in _visibleIndices()) {
      final b = _blocks[i];
      if (b == moved) continue;
      final box = _rowKeys[b.id]?.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.attached) continue;
      final centerY = box.localToGlobal(box.size.center(Offset.zero)).dy;
      if (dropY < centerY) {
        before = b;
        break;
      }
    }
    _moveBefore(moved, before);
    _focusBlock(moved);
  }

  void _move(int direction) {
    final block = _active;
    if (block == null) return;
    final visible = _visibleIndices();
    final pos = visible.indexOf(_blocks.indexOf(block));
    final target = pos + direction;
    if (pos < 0 || target < 0 || target >= visible.length) return;
    setState(() {
      final a = visible[pos], b = visible[target];
      _blocks[a] = _blocks[b];
      _blocks[b] = block;
    });
    _markChanged();
    _focusBlock(block, cursor: _ctrlFor(block).selection.baseOffset);
  }

  /// Arrastrar y soltar. Si se mueve un título plegado, se mueve con todo su
  /// contenido oculto.
  void _onReorder(int oldVisible, int newVisible) {
    final visible = _visibleIndices().map((i) => _blocks[i]).toList();
    final moved = visible.removeAt(oldVisible);
    if (oldVisible == newVisible) return;
    // [newVisible] es la posición final; se suelta delante del bloque que
    // ocupa esa posición sin contar el que se mueve (null = al final)
    final before = newVisible < visible.length ? visible[newVisible] : null;
    _moveBefore(moved, before);
    _focusBlock(moved);
  }

  Future<void> _cropImage(NoteBlock block) async {
    final bytes = await FileStorage.read((path: block.imagePath, data: block.imageData));
    if (bytes == null || !mounted) {
      _snack('No se pudo leer la imagen');
      return;
    }
    final cropped = await Navigator.push<Uint8List>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => CropScreen(image: bytes, color: widget.notebookColor),
      ),
    );
    if (cropped == null || !mounted) return;
    final ref = await FileStorage.save(cropped, 'recorte.png', folder: 'note_images');
    setState(() => block.setImage(path: ref.path, data: ref.data));
    _markChanged();
  }

  void _deleteActive() {
    final block = _active;
    if (block == null) return;
    final visible = _visibleIndices();
    final pos = visible.indexOf(_blocks.indexOf(block));
    final neighbor = pos > 0
        ? _blocks[visible[pos - 1]]
        : (pos + 1 < visible.length ? _blocks[visible[pos + 1]] : null);
    setState(() => _removeBlock(block));
    _markChanged();
    _focusBlock(neighbor ?? _blocks.first);
  }

  void _focusEnd() {
    final last = _blocks.last;
    if (last.isImage || last.text.isNotEmpty) {
      final block = NoteBlock();
      setState(() => _blocks.add(block));
      _focusBlock(block);
    } else {
      _focusBlock(last);
    }
  }

  // ─── Guardar ──────────────────────────────────────────────────────────────

  Future<void> _save() async {
    final provider = context.read<AppProvider>();
    final title = _titleCtrl.text.trim();
    final isEmpty =
        _blocks.every((b) => !b.isImage && b.text.trim().isEmpty);

    if (title.isEmpty && isEmpty) {
      Navigator.pop(context);
      return;
    }

    if (widget.existingNote != null) {
      await provider.updateNote(widget.existingNote!.id, title, _blocks,
          tags: _tags);
    } else {
      await provider.addNote(widget.notebookId, title, _blocks,
          setId: widget.setId, tags: _tags);
    }
    if (mounted) Navigator.pop(context);
  }

  void _addTag(String tag) {
    tag = tag.trim();
    if (tag.isNotEmpty && !_tags.contains(tag)) {
      setState(() {
        _tags.add(tag);
        _hasChanges = true;
      });
    }
    _tagCtrl.clear();
  }

  // ─── UI ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colors = BrownieColors.of(context);
    final isEditing = widget.existingNote != null;

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        backgroundColor: widget.notebookColor.withAlpha(200),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          isEditing ? 'Editar nota' : 'Nueva nota',
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        actions: [
          if (_hasChanges || !isEditing)
            TextButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save_outlined,
                  color: Colors.white, size: 18),
              label: const Text('Guardar',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700)),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Focus(
              focusNode: _editorFocus,
              child: _buildScrollArea(colors),
            ),
          ),
          _buildToolbar(colors),
        ],
      ),
    );
  }

  Widget _buildScrollArea(BrownieColors colors) {
    final visible = _visibleIndices();
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(8, 20, 20, 0),
          sliver: SliverToBoxAdapter(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Título
                  Padding(
                    padding: const EdgeInsets.only(left: 30),
                    child: TextField(
                      controller: _titleCtrl,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: colors.text,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Título de la nota...',
                        hintStyle: TextStyle(
                            color: colors.subtext.withAlpha(160), fontSize: 24),
                        border: InputBorder.none,
                      ),
                      maxLines: 1,
                      textInputAction: TextInputAction.next,
                      onSubmitted: (_) => _focusBlock(_blocks.first, cursor: 0),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 30),
                    child: Divider(color: colors.divider),
                  ),
                  const SizedBox(height: 8),
                ],
            ),
          ),
        ),

        // Bloques (se pueden arrastrar desde la manija ⋮⋮)
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(0, 0, 20, 0),
          sliver: SliverReorderableList(
            itemCount: visible.length,
            onReorderItem: _onReorder,
            proxyDecorator: (child, _, _) => Material(
              color: Colors.transparent,
              elevation: 6,
              shadowColor: Colors.black26,
              child: child,
            ),
            itemBuilder: (context, pos) {
              final block = _blocks[visible[pos]];
              return _buildBlockRow(visible[pos], pos, colors,
                  key: ValueKey(block.id));
            },
          ),
        ),

        SliverPadding(
          padding: const EdgeInsets.fromLTRB(38, 0, 20, 24),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Zona para seguir escribiendo al final
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _focusEnd,
                  child: const SizedBox(height: 120, width: double.infinity),
                ),
                _buildTags(colors),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Fila de un bloque: manija para arrastrar + contenido
  Widget _buildBlockRow(int index, int visiblePos, BrownieColors colors,
      {required Key key}) {
    final block = _blocks[index];
    final showHandle = block.id == _hoveredId || block.id == _activeId;
    // La manija se alinea con la primera línea del bloque
    final lineHeight = block.isImage ? 32.0 : block.effectiveFontSize * 1.5;
    final topPadding = block.isImage ? 8.0 : _blockTopPadding(block);

    return KeyedSubtree(
      key: key,
      child: MouseRegion(
      // Para saber dónde está cada bloque al soltar una imagen
      key: _rowKeys.putIfAbsent(block.id, GlobalKey.new),
      onEnter: (_) => setState(() => _hoveredId = block.id),
      onExit: (_) {
        if (_hoveredId == block.id) setState(() => _hoveredId = null);
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: topPadding),
            child: AnimatedOpacity(
              opacity: showHandle ? 1 : 0,
              duration: const Duration(milliseconds: 120),
              child: ReorderableDragStartListener(
                index: visiblePos,
                child: MouseRegion(
                  cursor: SystemMouseCursors.grab,
                  child: Tooltip(
                    message: 'Arrastra para mover',
                    waitDuration: const Duration(milliseconds: 600),
                    child: SizedBox(
                      width: 30,
                      height: lineHeight,
                      child: Icon(Icons.drag_indicator,
                          size: 18, color: colors.subtext),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(child: _buildBlock(index, colors)),
        ],
      ),
      ),
    );
  }

  Widget _buildBlock(int index, BrownieColors colors) {
    final block = _blocks[index];
    final isActive = block.id == _activeId;

    if (block.isImage) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(32, 6, 0, 6),
        child: NoteImageBlock(
          block: block,
          selected: isActive,
          hovered: block.id == _hoveredId,
          color: widget.notebookColor,
          resizing: block.id == _resizingId,
          onSelect: () => _focusBlock(block),
          onStartResize: () {
            _focusBlock(block);
            setState(() => _resizingId = block.id);
          },
          onExitResize: () => setState(() => _resizingId = null),
          onResize: (factor, alignX) => setState(() {
            block.widthFactor = factor >= 0.995 ? null : factor;
            block.alignX = alignX;
          }),
          onChanged: _markChanged,
          onDrop: (dropY) => _dropBlock(block, dropY),
          onCrop: () => _cropImage(block),
          onDelete: () {
            _focusBlock(block);
            _deleteActive();
          },
        ),
      );
    }

    final fontSize = block.effectiveFontSize;
    final lineHeight = fontSize * 1.5;
    final checkedTodo = block.type == BlockType.todo && block.checked;

    final style = TextStyle(
      fontSize: fontSize,
      height: 1.5,
      color: checkedTodo
          ? colors.subtext
          : block.type == BlockType.quote
              ? colors.text.withAlpha(200)
              : colors.text,
      fontWeight: block.isHeading
          ? FontWeight.w800
          : block.bold
              ? FontWeight.w700
              : FontWeight.normal,
      fontStyle: block.italic || block.type == BlockType.quote
          ? FontStyle.italic
          : FontStyle.normal,
      decoration: TextDecoration.combine([
        if (block.underline) TextDecoration.underline,
        if (checkedTodo) TextDecoration.lineThrough,
      ]),
    );

    // Margen izquierdo: aquí vive la flechita de los títulos (como en Word)
    Widget gutter = const SizedBox(width: 32);
    if (block.isHeading) {
      final hidden = block.collapsed ? _hiddenCount(index) : 0;
      gutter = SizedBox(
        width: 32,
        height: lineHeight,
        child: Tooltip(
          message: block.collapsed
              ? 'Mostrar contenido ($hidden ${hidden == 1 ? 'bloque' : 'bloques'})'
              : 'Ocultar contenido',
          child: InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () => _toggleCollapse(block),
            child: AnimatedRotation(
              turns: block.collapsed ? -0.25 : 0,
              duration: const Duration(milliseconds: 150),
              child: Icon(Icons.arrow_drop_down,
                  size: 26, color: colors.subtext),
            ),
          ),
        ),
      );
    }

    Widget? marker;
    if (block.type == BlockType.bullet) {
      marker = SizedBox(
        width: 22,
        height: lineHeight,
        child: Center(
          child: Text('•',
              style: TextStyle(
                  fontSize: fontSize * 1.2,
                  color: colors.text,
                  height: 1)),
        ),
      );
    } else if (block.type == BlockType.todo) {
      marker = SizedBox(
        width: 30,
        height: lineHeight,
        child: Checkbox(
          value: block.checked,
          activeColor: widget.notebookColor,
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          onChanged: (v) {
            setState(() => block.checked = v ?? false);
            _markChanged();
          },
        ),
      );
    }

    final field = TextField(
      controller: _ctrlFor(block),
      focusNode: _focusFor(block),
      style: style,
      maxLines: null,
      keyboardType: TextInputType.multiline,
      textInputAction: TextInputAction.newline,
      cursorColor: widget.notebookColor,
      decoration: InputDecoration.collapsed(
        hintText: isActive && block.text.isEmpty ? _hintFor(block) : null,
        hintStyle: style.copyWith(
          color: colors.subtext.withAlpha(120),
          decoration: TextDecoration.none,
        ),
      ),
    );

    Widget content = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        gutter,
        ?marker,
        Expanded(child: field),
      ],
    );

    if (block.type == BlockType.quote) {
      content = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(width: 32),
          Expanded(
            child: Container(
              padding: const EdgeInsets.only(left: 12),
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(color: widget.notebookColor, width: 3),
                ),
              ),
              child: field,
            ),
          ),
        ],
      );
    }

    return Padding(
      padding: EdgeInsets.only(
        top: _blockTopPadding(block),
        bottom: 2,
      ),
      child: content,
    );
  }

  Widget _menuRow(IconData icon, String label) => Row(
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 10),
          Text(label),
        ],
      );

  double _blockTopPadding(NoteBlock block) =>
      block.isHeading ? 14 - block.headingLevel * 2.0 : 2;

  String _hintFor(NoteBlock block) => switch (block.type) {
        BlockType.heading1 => 'Título 1',
        BlockType.heading2 => 'Título 2',
        BlockType.heading3 => 'Título 3',
        BlockType.bullet => 'Elemento de lista',
        BlockType.todo => 'Tarea',
        BlockType.quote => 'Cita',
        _ => 'Escribe, o usa # título, - lista, [] tarea',
      };

  Widget _buildTags(BrownieColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Etiquetas',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: colors.subtext,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            ..._tags.map(
              (tag) => GestureDetector(
                onTap: () => setState(() {
                  _tags.remove(tag);
                  _hasChanges = true;
                }),
                child: TagBadge(
                  label: '✕ $tag',
                  color: widget.notebookColor,
                ),
              ),
            ),
            SizedBox(
              width: 150,
              child: TextField(
                controller: _tagCtrl,
                style: TextStyle(fontSize: 12, color: colors.text),
                decoration: InputDecoration(
                  hintText: '+ Etiqueta',
                  hintStyle: TextStyle(fontSize: 12, color: colors.subtext),
                  border: InputBorder.none,
                  isDense: true,
                ),
                onSubmitted: _addTag,
                textInputAction: TextInputAction.done,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildToolbar(BrownieColors colors) {
    final block = _active;
    final isText = block != null && !block.isImage;
    final accent = widget.notebookColor;

    Widget toggle(IconData icon, String tooltip, bool on, VoidCallback onTap) =>
        IconButton(
          tooltip: tooltip,
          isSelected: on,
          onPressed: isText ? onTap : null,
          icon: Icon(icon),
          color: colors.text,
          selectedIcon: Icon(icon, color: accent),
          style: IconButton.styleFrom(
            backgroundColor: on ? accent.withAlpha(40) : null,
          ),
        );

    final typeLabels = <BlockType, (IconData, String)>{
      BlockType.paragraph: (Icons.notes, 'Texto'),
      BlockType.heading1: (Icons.title, 'Título 1'),
      BlockType.heading2: (Icons.title, 'Título 2'),
      BlockType.heading3: (Icons.title, 'Título 3'),
      BlockType.bullet: (Icons.format_list_bulleted, 'Lista'),
      BlockType.todo: (Icons.check_box_outlined, 'Lista de tareas'),
      BlockType.quote: (Icons.format_quote, 'Cita'),
    };

    // Los toques en la barra no deben cerrar el teclado
    return TextFieldTapRegion(
      child: Material(
        color: colors.surface,
        child: SafeArea(
          top: false,
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: colors.divider)),
            ),
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              children: [
                PopupMenuButton<BlockType>(
                  tooltip: 'Tipo de bloque',
                  enabled: isText,
                  onSelected: _setType,
                  itemBuilder: (_) => [
                    for (final e in typeLabels.entries)
                      PopupMenuItem(
                        value: e.key,
                        child: Row(
                          children: [
                            Icon(e.value.$1, size: 18,
                                color: block?.type == e.key ? accent : null),
                            const SizedBox(width: 10),
                            Text(e.value.$2),
                          ],
                        ),
                      ),
                  ],
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      children: [
                        Icon(typeLabels[block?.type]?.$1 ?? Icons.notes,
                            color: isText ? colors.text : colors.subtext),
                        const SizedBox(width: 4),
                        Text(
                          typeLabels[block?.type]?.$2 ?? 'Texto',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isText ? colors.text : colors.subtext,
                          ),
                        ),
                        Icon(Icons.arrow_drop_down,
                            color: isText ? colors.text : colors.subtext),
                      ],
                    ),
                  ),
                ),
                const VerticalDivider(width: 12, indent: 12, endIndent: 12),
                IconButton(
                  tooltip: 'Reducir letra',
                  onPressed: isText ? () => _changeFontSize(-1) : null,
                  icon: const Icon(Icons.text_decrease),
                  color: colors.text,
                ),
                Center(
                  child: SizedBox(
                    width: 28,
                    child: Text(
                      isText ? block.effectiveFontSize.round().toString() : '–',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontWeight: FontWeight.w700, color: colors.text),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Aumentar letra',
                  onPressed: isText ? () => _changeFontSize(1) : null,
                  icon: const Icon(Icons.text_increase),
                  color: colors.text,
                ),
                const VerticalDivider(width: 12, indent: 12, endIndent: 12),
                toggle(Icons.format_bold, 'Negrita', block?.bold ?? false,
                    () => _edit((b) => b.bold = !b.bold)),
                toggle(Icons.format_italic, 'Cursiva', block?.italic ?? false,
                    () => _edit((b) => b.italic = !b.italic)),
                toggle(Icons.format_underline, 'Subrayado',
                    block?.underline ?? false,
                    () => _edit((b) => b.underline = !b.underline)),
                const VerticalDivider(width: 12, indent: 12, endIndent: 12),
                if (noteImagesEnabled)
                PopupMenuButton<String>(
                  tooltip: 'Agregar imagen',
                  icon: Icon(Icons.add_photo_alternate_outlined,
                      color: colors.text),
                  onSelected: (v) => switch (v) {
                    'camera' => _insertImage(ImageSource.camera),
                    'paste' => _pasteImage(),
                    _ => _insertImage(ImageSource.gallery),
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'gallery',
                      child: _menuRow(Icons.photo_library_outlined,
                          FileStorage.canUseCamera ? 'Galería' : 'Desde archivo'),
                    ),
                    if (FileStorage.canUseCamera)
                      PopupMenuItem(
                        value: 'camera',
                        child: _menuRow(Icons.photo_camera_outlined, 'Cámara'),
                      ),
                    PopupMenuItem(
                      value: 'paste',
                      child: _menuRow(Icons.content_paste,
                          'Pegar del portapapeles${FileStorage.canUseCamera ? '' : '  (Ctrl+V)'}'),
                    ),
                  ],
                ),
                IconButton(
                  tooltip: 'Subir bloque',
                  onPressed: block != null ? () => _move(-1) : null,
                  icon: const Icon(Icons.arrow_upward),
                  color: colors.text,
                ),
                IconButton(
                  tooltip: 'Bajar bloque',
                  onPressed: block != null ? () => _move(1) : null,
                  icon: const Icon(Icons.arrow_downward),
                  color: colors.text,
                ),
                IconButton(
                  tooltip: 'Eliminar bloque',
                  onPressed: block != null ? _deleteActive : null,
                  icon: const Icon(Icons.delete_outline),
                  color: colors.text,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
