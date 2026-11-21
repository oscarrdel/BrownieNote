import 'dart:math' as math;

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/note_block.dart';
import '../services/file_storage.dart';

/// Imagen dentro de una nota, con el comportamiento de Word:
/// - un clic la selecciona (y muestra acciones rápidas)
/// - seleccionada, se arrastra libremente: a los lados queda donde se suelta
///   y arriba/abajo se reacomoda entre los bloques
/// - doble clic activa el modo de tamaño: 8 puntos en esquinas y lados; el
///   lado contrario al punto que se jala se queda fijo
/// - clic fuera o Esc sale del modo de tamaño
class NoteImageBlock extends StatefulWidget {
  final NoteBlock block;
  final bool selected;
  final bool hovered;

  /// Modo de tamaño activo (los puntos están visibles)
  final bool resizing;
  final Color color;
  final VoidCallback onSelect;
  final VoidCallback onStartResize;
  final VoidCallback onExitResize;

  /// Nuevo ancho (fracción) y posición horizontal (-1..1)
  final void Function(double widthFactor, double alignX) onResize;

  /// Se terminó de cambiar tamaño o posición: hay cambios que guardar
  final VoidCallback onChanged;

  /// Se soltó la imagen después de moverla; [dropY] es la posición vertical
  /// global donde quedó su centro, para reacomodarla entre los bloques
  final ValueChanged<double> onDrop;
  final VoidCallback onCrop;
  final VoidCallback onDelete;

  const NoteImageBlock({
    super.key,
    required this.block,
    required this.selected,
    required this.hovered,
    required this.resizing,
    required this.color,
    required this.onSelect,
    required this.onStartResize,
    required this.onExitResize,
    required this.onResize,
    required this.onChanged,
    required this.onDrop,
    required this.onCrop,
    required this.onDelete,
  });

  @override
  State<NoteImageBlock> createState() => _NoteImageBlockState();
}

class _NoteImageBlockState extends State<NoteImageBlock> {
  static const _minFactor = 0.1;
  static const _handleSize = 11.0;
  static const _hitSize = 28.0;

  final _imageKey = GlobalKey();

  // Cambio de tamaño en curso
  bool _resizingNow = false;
  Size _startSize = Size.zero;
  double _startAlign = -1;
  Offset _dragTotal = Offset.zero;

  // Movimiento en curso
  bool _moving = false;
  double _moveDy = 0;
  double _grabOffsetY = 0;
  double _pointerY = 0;

  double get _factor => widget.block.widthFactor ?? 1.0;
  double get _align => widget.block.alignX ?? -1.0;

  /// Borde izquierdo de la imagen dentro del ancho disponible
  static double _leftOf(double align, double width, double maxWidth) =>
      (align + 1) / 2 * (maxWidth - width);

  /// Posición horizontal que deja el borde izquierdo en [left]
  static double _alignFor(double left, double width, double maxWidth,
      {required double fallback}) {
    final free = maxWidth - width;
    if (free <= 0.5) return fallback;
    return (2 * left / free - 1).clamp(-1.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final block = widget.block;
    final busy = _resizingNow || _moving;
    final showActions =
        (widget.selected || widget.hovered || widget.resizing) && !busy;

    return LayoutBuilder(builder: (context, constraints) {
      final maxWidth = constraints.maxWidth;
      final width = maxWidth * _factor;

      /// Punto de una esquina. [sx]/[sy]: -1 izquierda/arriba, 1 derecha/abajo
      Widget handle(int sx, int sy) {
        final cursor = sx == sy
            ? SystemMouseCursors.resizeUpLeftDownRight
            : SystemMouseCursors.resizeUpRightDownLeft;
        const offset = -_hitSize / 2;
        return Positioned(
          left: sx == -1 ? offset : null,
          right: sx == 1 ? offset : null,
          top: sy == -1 ? offset : null,
          bottom: sy == 1 ? offset : null,
          child: _handleWidget(sx, sy, cursor, maxWidth),
        );
      }

      // Punto en medio de un lado: se centra con Align para no depender del
      // tamaño de la imagen. Uno de [sx]/[sy] es 0.
      Widget midHandle(int sx, int sy) {
        final cursor = sx == 0
            ? SystemMouseCursors.resizeUpDown
            : SystemMouseCursors.resizeLeftRight;
        return Positioned(
          left: sx == 1 ? null : (sx == -1 ? -_hitSize / 2 : 0),
          right: sx == -1 ? null : (sx == 1 ? -_hitSize / 2 : 0),
          top: sy == 1 ? null : (sy == -1 ? -_hitSize / 2 : 0),
          bottom: sy == -1 ? null : (sy == 1 ? -_hitSize / 2 : 0),
          child: Align(child: _handleWidget(sx, sy, cursor, maxWidth)),
        );
      }

      final canMove = widget.selected || widget.resizing;

      final image = GestureDetector(
        onTap: widget.onSelect,
        onDoubleTap: widget.onStartResize,
        // Arrastrar la imagen seleccionada la mueve libremente. Con "down"
        // la imagen sigue al mouse desde el primer pixel.
        dragStartBehavior: DragStartBehavior.down,
        onPanStart: canMove
            ? (d) {
                final box =
                    _imageKey.currentContext?.findRenderObject() as RenderBox?;
                final centerY =
                    box?.localToGlobal(box.size.center(Offset.zero)).dy;
                setState(() {
                  _moving = true;
                  _moveDy = 0;
                  // Distancia entre el dedo/mouse y el centro de la imagen
                  _grabOffsetY = d.globalPosition.dy - (centerY ?? d.globalPosition.dy);
                  _pointerY = d.globalPosition.dy;
                });
              }
            : null,
        onPanUpdate: canMove
            ? (d) {
                _pointerY = d.globalPosition.dy;
                setState(() => _moveDy += d.delta.dy);
                final left = _leftOf(_align, width, maxWidth) + d.delta.dx;
                widget.onResize(
                    _factor,
                    _alignFor(left.clamp(0, maxWidth - width), width, maxWidth,
                        fallback: _align));
              }
            : null,
        onPanEnd: canMove ? (_) => _endMove() : null,
        onPanCancel: canMove ? _endMove : null,
        child: MouseRegion(
          cursor: canMove ? SystemMouseCursors.move : MouseCursor.defer,
          child: Container(
            key: _imageKey,
            // Llena el ancho elegido para que los puntos queden en las
            // esquinas reales de la imagen
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.resizing ? 2 : 10),
              border: Border.all(
                color: widget.selected || widget.resizing
                    ? widget.color
                    : Colors.transparent,
                width: widget.resizing ? 1.5 : 2,
              ),
              boxShadow: _moving
                  ? const [BoxShadow(color: Colors.black38, blurRadius: 16)]
                  : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(widget.resizing ? 0 : 8),
              child: StoredImage(
                ref: (path: block.imagePath, data: block.imageData),
                bytes: block.imageBytes,
              ),
            ),
          ),
        ),
      );

      return Align(
        alignment: Alignment(_align, 0),
        child: Transform.translate(
          offset: Offset(0, _moveDy),
          child: TapRegion(
            // Clic fuera de la imagen: sale del modo de tamaño
            onTapOutside: (_) {
              if (widget.resizing && !busy) widget.onExitResize();
            },
            child: SizedBox(
              width: width,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Opacity(
                    opacity: _moving ? 0.85 : 1,
                    // Con la imagen seleccionada, arrastrarla empieza un poco
                    // antes que el scroll de la nota (en pantallas táctiles
                    // el scroll se la ganaría al moverla hacia arriba/abajo)
                    child: canMove
                        ? MediaQuery(
                            data: MediaQuery.of(context).copyWith(
                                gestureSettings:
                                    const DeviceGestureSettings(touchSlop: 8)),
                            child: image,
                          )
                        : image,
                  ),
                  if (widget.resizing && !_moving) ...[
                    handle(-1, -1),
                    handle(1, -1),
                    handle(-1, 1),
                    handle(1, 1),
                    midHandle(0, -1),
                    midHandle(0, 1),
                    midHandle(-1, 0),
                    midHandle(1, 0),
                  ],
                  if (showActions) _actions(),
                  if (busy || widget.selected)
                    Positioned(
                      bottom: 10,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: _Pill(
                          text: _resizingNow
                              ? '${(_factor * 100).round()}%'
                              : _moving
                                  ? 'Suelta donde la quieras'
                                  : widget.resizing
                                      ? 'Jala los puntos · Esc para terminar'
                                      : 'Arrástrala para moverla · '
                                          'doble clic para el tamaño',
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }

  void _endMove() {
    if (!_moving) return;
    // Centro de la imagen donde se soltó, según la posición real del
    // mouse/dedo (no depende de que la pantalla ya se haya redibujado)
    final centerY = _pointerY - _grabOffsetY;
    final movedVertically = _moveDy.abs() > 24;
    setState(() {
      _moving = false;
      _moveDy = 0;
    });
    widget.onChanged();
    if (movedVertically) widget.onDrop(centerY);
  }

  Widget _actions() {
    void align(double x) {
      widget.onResize(_factor, x);
      widget.onChanged();
    }

    return Positioned(
      top: 10,
      right: 18,
      child: Material(
        color: Colors.black.withAlpha(150),
        borderRadius: BorderRadius.circular(10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ImageAction(
              icon: Icons.format_align_left,
              tooltip: 'A la izquierda',
              onTap: () => align(-1),
            ),
            _ImageAction(
              icon: Icons.format_align_center,
              tooltip: 'Al centro',
              onTap: () => align(0),
            ),
            _ImageAction(
              icon: Icons.format_align_right,
              tooltip: 'A la derecha',
              onTap: () => align(1),
            ),
            Container(width: 1, height: 20, color: Colors.white24),
            _ImageAction(
              icon: Icons.crop,
              tooltip: 'Recortar',
              onTap: widget.onCrop,
            ),
            PopupMenuButton<double>(
              tooltip: 'Tamaño',
              onSelected: (f) {
                widget.onResize(f, _align);
                widget.onChanged();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 0.25, child: Text('Pequeña (25%)')),
                PopupMenuItem(value: 0.5, child: Text('Mediana (50%)')),
                PopupMenuItem(value: 0.75, child: Text('Grande (75%)')),
                PopupMenuItem(value: 1.0, child: Text('Ancho completo')),
              ],
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(Icons.photo_size_select_large,
                    size: 18, color: Colors.white),
              ),
            ),
            _ImageAction(
              icon: Icons.delete_outline,
              tooltip: 'Eliminar imagen',
              onTap: widget.onDelete,
            ),
          ],
        ),
      ),
    );
  }

  Widget _handleWidget(int sx, int sy, MouseCursor cursor, double maxWidth) {
    return MouseRegion(
      cursor: cursor,
      // Se queda con el gesto en cuanto se toca el punto, para que el scroll
      // de la nota no se lo gane (sobre todo en pantallas táctiles)
      child: RawGestureDetector(
        behavior: HitTestBehavior.opaque,
        gestures: {
          _EagerPanGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<_EagerPanGestureRecognizer>(
            _EagerPanGestureRecognizer.new,
            (r) => r
              ..onStart = (_) {
                final box =
                    _imageKey.currentContext?.findRenderObject() as RenderBox?;
                setState(() {
                  _resizingNow = true;
                  _startSize = box?.size ?? Size(maxWidth, maxWidth);
                  _startAlign = _align;
                  _dragTotal = Offset.zero;
                });
              }
              ..onUpdate = (d) {
                _dragTotal += d.delta;
                _applyResize(sx, sy, maxWidth);
              }
              ..onEnd = (_) {
                setState(() => _resizingNow = false);
                widget.onChanged();
              },
          ),
        },
        child: SizedBox(
          width: _hitSize,
          height: _hitSize,
          child: Center(
            child: Container(
              width: _handleSize,
              height: _handleSize,
              decoration: BoxDecoration(
                color: Colors.white,
                shape:
                    sx != 0 && sy != 0 ? BoxShape.rectangle : BoxShape.circle,
                border: Border.all(color: widget.color, width: 1.5),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 3),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Nuevo tamaño según cuánto se ha jalado el punto. La imagen conserva su
  /// proporción y el lado contrario al punto se queda en su lugar.
  void _applyResize(int sx, int sy, double maxWidth) {
    final w = _startSize.width;
    final h = _startSize.height <= 0 ? w : _startSize.height;
    final fromX = sx * _dragTotal.dx;
    // Jalar hacia abajo agranda la altura; se convierte a ancho
    final fromY = sy * _dragTotal.dy * (w / h);
    final deltaWidth = sx == 0
        ? fromY
        : sy == 0
            ? fromX
            : (fromX.abs() > fromY.abs() ? fromX : fromY);

    final startLeft = _leftOf(_startAlign, w, maxWidth);
    // Si se jala desde la izquierda, el borde derecho queda fijo
    final maxW = sx == -1 ? startLeft + w : maxWidth - startLeft;
    final upper = maxW.clamp(1.0, maxWidth).toDouble();
    final newWidth =
        (w + deltaWidth).clamp(math.min(maxWidth * _minFactor, upper), upper).toDouble();
    final newLeft = sx == -1 ? startLeft + w - newWidth : startLeft;

    widget.onResize(
      newWidth / maxWidth,
      _alignFor(newLeft, newWidth, maxWidth, fallback: _startAlign),
    );
  }
}

/// Arrastre que gana de inmediato, sin esperar a que el dedo se mueva
class _EagerPanGestureRecognizer extends PanGestureRecognizer {
  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    resolve(GestureDisposition.accepted);
  }
}

class _Pill extends StatelessWidget {
  final String text;
  const _Pill({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(160),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(
            color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _ImageAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _ImageAction(
      {required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 18, color: Colors.white),
        ),
      ),
    );
  }
}

/// Pantalla para recortar una imagen. Devuelve los bytes recortados.
class CropScreen extends StatefulWidget {
  final Uint8List image;
  final Color color;

  const CropScreen({super.key, required this.image, required this.color});

  @override
  State<CropScreen> createState() => _CropScreenState();
}

class _CropScreenState extends State<CropScreen> {
  final _controller = CropController();
  double? _aspectRatio;
  bool _cropping = false;

  static const _ratios = <String, double?>{
    'Libre': null,
    '1:1': 1,
    '4:3': 4 / 3,
    '16:9': 16 / 9,
    '3:4': 3 / 4,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Recortar imagen'),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: FilledButton.icon(
              onPressed: _cropping
                  ? null
                  : () {
                      setState(() => _cropping = true);
                      _controller.crop();
                    },
              style: FilledButton.styleFrom(backgroundColor: widget.color),
              icon: _cropping
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check),
              label: const Text('Listo'),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Crop(
              image: widget.image,
              controller: _controller,
              aspectRatio: _aspectRatio,
              baseColor: Colors.black,
              maskColor: Colors.black.withAlpha(150),
              onCropped: (result) {
                switch (result) {
                  case CropSuccess(:final croppedImage):
                    Navigator.pop(context, croppedImage);
                  case CropFailure():
                    setState(() => _cropping = false);
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('No se pudo recortar')));
                }
              },
            ),
          ),
          SafeArea(
            top: false,
            child: SizedBox(
              height: 56,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                children: [
                  for (final e in _ratios.entries)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(e.key),
                        selected: _aspectRatio == e.value,
                        selectedColor: widget.color,
                        labelStyle: TextStyle(
                          color: _aspectRatio == e.value
                              ? Colors.white
                              : Colors.white70,
                        ),
                        backgroundColor: Colors.white12,
                        showCheckmark: false,
                        onSelected: (_) {
                          setState(() => _aspectRatio = e.value);
                          _controller.aspectRatio = e.value;
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
