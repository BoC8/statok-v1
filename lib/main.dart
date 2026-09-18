import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'pages/coquille.dart';
import 'supabase_config.dart';
import 'theme/app_theme.dart';

/// Le point d'entrée.
///
///   Les quatre écrans publics vivent derrière la barre d'onglets ;
///   l'espace coachs s'ouvre depuis le dernier. Tout part de `Coquille`.
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

      // UNE TAPE À CÔTÉ REFERME LE CLAVIER
      //   Sur les formulaires de l'espace coachs, le clavier restait
      //   ouvert tant qu'on ne validait pas : il mangeait la moitié de
      //   l'écran, cachait le bouton « Enregistrer », et rien de ce
      //   qu'on touchait à côté ne le faisait partir.
      //
      //   Ce détecteur est posé au-dessus de toute l'application, mais
      //   il ne vole rien : un appui sur un bouton, un champ ou une
      //   liste est réclamé par le widget concerné, qui est plus
      //   profond dans l'arbre et l'emporte dans l'arène des gestes.
      //   Seules les tapes qui ne visaient rien arrivent jusqu'ici.
      builder: (context, enfant) => GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: enfant,
      ),
    );
  }
}
