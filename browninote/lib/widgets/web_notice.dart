import 'package:flutter/material.dart';

/// Aviso fino que aparece solo en la versión web. Tus datos se quedan en el
/// navegador; si borras los datos del sitio, se pierden.
class WebNotice extends StatelessWidget {
  const WebNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(
            'Versión web de prueba. Tus datos se guardan solo en este navegador.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
        ),
      ),
    );
  }
}
