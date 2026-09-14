import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'pages/coquille.dart';
import 'supabase_config.dart';
import 'theme/app_theme.dart';

/// REFONTE EN COURS
///   Les quatre écrans publics sont en place derrière la barre
///   d'onglets. L'espace coachs reste à écrire.
///
///   Les anciennes pages sont encore dans `lib/pages/` mais plus
///   personne ne les atteint : elles interrogent des tables qui
///   n'existent plus dans le schéma v2. On les supprimera au fur et à
///   mesure que leurs remplaçantes seront validées.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  await initializeDateFormatting('fr_FR', null);

  runApp(const ProviderScope(child: StatokApp()));
}

class StatokApp extends StatelessWidget {
  const StatokApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'STATOK',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      locale: const Locale('fr', 'FR'),
      supportedLocales: const [Locale('fr', 'FR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const Coquille(),
    );
  }
}
