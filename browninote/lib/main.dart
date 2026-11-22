import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/app_provider.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';
import 'widgets/web_notice.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppProvider()..loadData(),
      child: const BrownieNoteApp(),
    ),
  );
}

class BrownieNoteApp extends StatelessWidget {
  const BrownieNoteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BrownieNote',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      builder: (context, child) {
        if (!kIsWeb || child == null) return child ?? const SizedBox.shrink();
        // Tarjeta flotante en la esquina inferior izquierda: no empuja el
        // diseño de la app.
        return Stack(
          children: [
            child,
            const Positioned(
              left: 12,
              bottom: 12,
              child: SafeArea(
                top: false,
                child: WebNotice(),
              ),
            ),
          ],
        );
      },
      home: const HomeScreen(),
    );
  }
}
