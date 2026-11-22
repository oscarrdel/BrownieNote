import 'package:flutter/material.dart';

/// Franja discreta que aparece solo en la versión web. Tus datos se quedan
/// en el navegador; si borras los datos del sitio, se pierden.
class WebNotice extends StatelessWidget {
  const WebNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.primary.withValues(alpha: 0.10),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 30,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.info_outline, size: 14, color: scheme.primary),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'Versión web de prueba · tus datos se quedan en este navegador',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: scheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
