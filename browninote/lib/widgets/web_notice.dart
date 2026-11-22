import 'package:flutter/material.dart';

/// Tarjeta flotante que aparece solo en la versión web. Tus datos se quedan
/// en el navegador; si borras los datos del sitio, se pierden.
class WebNotice extends StatelessWidget {
  const WebNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      elevation: 4,
      shadowColor: scheme.primary.withValues(alpha: 0.25),
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.info_outline, size: 16, color: scheme.primary),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'Versión web de prueba · tus datos se quedan en este navegador',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: scheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
