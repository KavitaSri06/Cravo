import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app/router.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const CravoApp());
}

class CravoApp extends StatefulWidget {
  const CravoApp({super.key});

  @override
  State<CravoApp> createState() => _CravoAppState();
}

class _CravoAppState extends State<CravoApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Cravo',
      debugShowCheckedModeBanner: false,
      routerConfig: appRouter,
      theme: ThemeData.dark().copyWith(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF0A0F1E),
        cardColor: const Color(0xFF111827),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1A56A0),
          brightness: Brightness.dark,
          primary: const Color(0xFF1A56A0),
          secondary: const Color(0xFF4DA3FF),
        ),
        textTheme: ThemeData.dark().textTheme.apply(
              bodyColor: Colors.white,
              displayColor: Colors.white,
            ),
      ),
    );
  }
}
