import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_providers.dart';
import '../theme/app_theme.dart';
import 'accueil_page.dart';
import 'classements_page.dart';
import 'coach/coach_accueil_page.dart';
import 'coach/connexion_page.dart';
import 'equipes_page.dart';
import 'matchs_page.dart';

/// La charpente de l'application : cinq onglets, une barre en bas.
///
/// POURQUOI UN `IndexedStack` ET PAS UN SIMPLE `switch`
///   Chaque onglet garde son état — le filtre choisi, la position de
///   défilement, le segment actif. Revenir sur le calendrier après un
///   détour par les classements ne remet pas les puces à zéro, et ne
///   relance aucun chargement.
class Coquille extends StatefulWidget {
  const Coquille({super.key});

  @override
  State<Coquille> createState() => _CoquilleState();
}

class _CoquilleState extends State<Coquille> {
  int _onglet = 0;

  /// Permet à l'accueil de piloter l'onglet Matchs — « Tout voir » doit
  /// ouvrir les résultats, pas le programme.
  final _matchs = GlobalKey<MatchsPageState>();

  void _allerAuxMatchs({bool resultats = false}) {
    setState(() => _onglet = 1);
    if (resultats) {
      // Après la bascule, pour que la page existe déjà.
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _matchs.currentState?.afficherResultats(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      AccueilPage(
        onAllerAuxMatchs: () => _allerAuxMatchs(resultats: true),
        onAllerAuxStats: () => setState(() => _onglet = 3),
      ),
      MatchsPage(key: _matchs),
      const EquipesPage(),
      const ClassementsPage(),
      const _EspaceCoachs(),
    ];

    return Scaffold(
      backgroundColor: Couleurs.craie,
      body: IndexedStack(index: _onglet, children: pages),
      bottomNavigationBar: _BarreOnglets(
        actif: _onglet,
        onChoix: (i) => setState(() => _onglet = i),
      ),
    );
  }
}

class _BarreOnglets extends StatelessWidget {
  const _BarreOnglets({required this.actif, required this.onChoix});

  final int actif;
  final ValueChanged<int> onChoix;

  static const _onglets = <(IconData, String)>[
    (Icons.home_outlined, 'Accueil'),
    (Icons.calendar_today_outlined, 'Matchs'),
    (Icons.groups_outlined, 'Équipes'),
    (Icons.emoji_events_outlined, 'Classements'),
    (Icons.lock_outline, 'Coachs'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Couleurs.blanc,
        border: Border(top: BorderSide(color: Couleurs.ligne)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom,
      ),
      child: Row(
        children: [
          for (var i = 0; i < _onglets.length; i++)
            Expanded(
              child: _Onglet(
                icone: _onglets[i].$1,
                libelle: _onglets[i].$2,
                choisi: i == actif,
                onTap: () => onChoix(i),
              ),
            ),
        ],
      ),
    );
  }
}

class _Onglet extends StatelessWidget {
  const _Onglet({
    required this.icone,
    required this.libelle,
    required this.choisi,
    required this.onTap,
  });

  final IconData icone;
  final String libelle;
  final bool choisi;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final couleur = choisi ? Couleurs.bleu : Couleurs.gris2;

    return InkWell(
      onTap: onTap,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 9, 2, 11),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icone, size: 19, color: couleur),
                const SizedBox(height: 4),
                Text(
                  libelle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Typo.texte(
                    taille: 9.5,
                    graisse: 600,
                    couleur: couleur,
                    hauteurLigne: 1,
                  ),
                ),
              ],
            ),
          ),
          // Le liseré bleu au-dessus de l'onglet actif.
          if (choisi)
            Container(
              width: 26,
              height: 2.5,
              decoration: const BoxDecoration(
                color: Couleurs.bleu,
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(3),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// L'aiguillage de l'espace coachs : connexion ou tableau de bord.
///
/// On ne décide pas d'après un booléen local mais d'après la session
/// Supabase elle-même. Si elle expire pendant que l'app est ouverte, le
/// staff retombe sur l'écran de connexion sans qu'on ait à y penser.
class _EspaceCoachs extends ConsumerWidget {
  const _EspaceCoachs();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profil = ref.watch(profilProvider);

    return profil.when(
      loading: () => const Scaffold(
        backgroundColor: Couleurs.nuit,
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      ),
      // Une erreur de lecture du profil ne doit pas ouvrir la porte :
      // en cas de doute, on demande de se connecter.
      error: (_, _) => const ConnexionPage(),
      data: (p) => p == null
          ? const ConnexionPage()
          : const CoachAccueilPage(),
    );
  }
}
