import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/file_storage.dart';
import '../theme/app_theme.dart';

extension AttachmentRef on Attachment {
  StoredRef get ref => (path: path, data: data);
}

/// Abre un adjunto: las imágenes dentro de la app, lo demás con su programa
Future<void> openAttachment(BuildContext context, Attachment a) async {
  if (a.isImage) {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ImageViewerScreen(attachment: a)),
    );
    return;
  }
  final error = await FileStorage.open(a.ref);
  if (error != null && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('No se pudo abrir "${a.name}": $error')),
    );
  }
}

({IconData icon, Color color}) _fileStyle(String ext) => switch (ext) {
      'pdf' => (icon: Icons.picture_as_pdf, color: const Color(0xFFE5524E)),
      'doc' || 'docx' || 'odt' || 'rtf' =>
        (icon: Icons.description, color: const Color(0xFF4E7FE5)),
      'xls' || 'xlsx' || 'csv' || 'ods' =>
        (icon: Icons.table_chart, color: const Color(0xFF3FBF94)),
      'ppt' || 'pptx' || 'odp' =>
        (icon: Icons.slideshow, color: const Color(0xFFE5734E)),
      'txt' || 'md' => (icon: Icons.article, color: const Color(0xFF9B96C4)),
      'zip' || 'rar' || '7z' =>
        (icon: Icons.folder_zip, color: const Color(0xFFE5A84E)),
      'mp3' || 'wav' || 'm4a' =>
        (icon: Icons.audiotrack, color: const Color(0xFFD74EE5)),
      'mp4' || 'mov' || 'avi' =>
        (icon: Icons.movie, color: const Color(0xFFD74EE5)),
      _ => (icon: Icons.insert_drive_file, color: const Color(0xFF9B96C4)),
    };

/// Cuadrícula de adjuntos. Con [onRemove] muestra el botón para quitarlos.
class AttachmentGrid extends StatelessWidget {
  final List<Attachment> attachments;
  final void Function(Attachment)? onRemove;

  const AttachmentGrid({super.key, required this.attachments, this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final a in attachments)
          _AttachmentTile(
            attachment: a,
            onRemove: onRemove == null ? null : () => onRemove!(a),
          ),
      ],
    );
  }
}

class _AttachmentTile extends StatelessWidget {
  final Attachment attachment;
  final VoidCallback? onRemove;

  const _AttachmentTile({required this.attachment, this.onRemove});

  @override
  Widget build(BuildContext context) {
    final colors = BrownieColors.of(context);
    final a = attachment;
    final style = _fileStyle(a.extension);

    final content = a.isImage
        ? StoredImage(ref: a.ref, fit: BoxFit.cover)
        : Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(style.icon, color: style.color, size: 30),
                const Spacer(),
                Text(
                  a.name,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colors.text,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${a.extension.toUpperCase()} · ${a.sizeLabel}',
                  style: TextStyle(fontSize: 10, color: colors.subtext),
                ),
              ],
            ),
          );

    return Tooltip(
      message: a.name,
      child: SizedBox(
        width: 120,
        height: 120,
        child: Stack(
          children: [
            Positioned.fill(
              child: Material(
                color: a.isImage ? Colors.black12 : style.color.withAlpha(22),
                borderRadius: BorderRadius.circular(12),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => openAttachment(context, a),
                  child: content,
                ),
              ),
            ),
            if (onRemove != null)
              Positioned(
                top: 4,
                right: 4,
                child: Material(
                  color: Colors.black54,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onRemove,
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.close, size: 14, color: Colors.white),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Visor de imagen a pantalla completa con zoom
class ImageViewerScreen extends StatelessWidget {
  final Attachment attachment;
  const ImageViewerScreen({super.key, required this.attachment});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(attachment.name, style: const TextStyle(fontSize: 15)),
        actions: [
          if (FileStorage.canOpenExternally && attachment.path != null)
            IconButton(
              tooltip: 'Abrir con otra app',
              icon: const Icon(Icons.open_in_new),
              onPressed: () => FileStorage.open(attachment.ref),
            ),
        ],
      ),
      body: InteractiveViewer(
        maxScale: 6,
        child: Center(child: StoredImage(ref: attachment.ref)),
      ),
    );
  }
}
