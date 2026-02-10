import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';

// Importe tes fichiers
import 'pages/home_page.dart';
import 'theme/app_theme.dart';
import 'supabase_config.dart'; // <-- On importe tes clés ici

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialisation Supabase avec les constantes de ton fichier config
  await Supabase.initialize(
    url: supabaseUrl,      // Assure-toi que la variable s'appelle bien comme ça dans supabase_config.dart
    anonKey: supabaseAnonKey,
  );

  // Formatage des dates en français
  await initializeDateFormatting('fr_FR', null);

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GJPB App',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const HomePage(),
    );
  }
}