import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/rencontre.dart';
import '../providers/club_providers.dart';
import '../providers/donnees_saison.dart';
import '../theme/app_theme.dart';
import '../widgets/communs.dart';
import '../widgets/entete.dart';
import '../widgets/filtres.dart';
import '../widgets/ligne_match.dart';
import 'joueur_page.dart';

/// Le calendrier : les rencontres à venir et les résultats, ensemble.
///
/// UN SEUL ÉCRAN, DEUX VUES
///   L'ancienne application séparait « Calendrier » et « Résultats » en
///   deux pages, alors qu'il s'agit des mêmes rencontres à deux moments
///   de leur vie. Un segment suffit, et le filtre reste le même quand on
///   bascule de l'un à l'autre.
class MatchsPage extends ConsumerStatefulWidget {
  const MatchsPage({super.key, this.vueInitiale = 'avenir'});

  final String vueInitiale;

  @override
  ConsumerState<MatchsPage> createState() => MatchsPageState();
}

class MatchsPageState extends ConsumerState<MatchsPage> {
  late String _vue = widget.vueInitiale;
  FiltreClub _filtre = const FiltreClub();

  /// Permet à l'accueil de demander l'ouverture sur les résultats.
  void afficherResultats() => setState(() => _vue = 'resultats');

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(donneesSaisonProvider);
    final saison = ref.watch(saisonCouranteProvider).value;
    final archive = saison != null && !saison.enCours;

    // Sur une saison terminée, « à venir » n'a plus de sens.
    final vue = archive ? 'resultats' : _vue;

    return Scaffold(
      backgroundColor: Couleurs.craie,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            EnteteSimple(
              // Pas de sous-titre : la saison se lit dans le sélecteur
              // juste à droite, et le segment ci-dessous dit déjà ce
              // qu'on regarde.
              // Le titre reprend le mot de l'onglet du bas : « Matchs ».
              // Deux noms pour le même écran — « Calendrier » en haut,
              // « Matchs » en bas — faisaient douter d'être au bon
              // endroit.
              titre: 'Matchs',
              selecteur: const SelecteurSaison(),
              dessous: archive
                  ? null
                  : Segments(
                      options: const [
                        ('avenir', 'À venir'),
                        ('resultats', 'Résultats'),
                      ],
                      actif: vue,
                      onChoix: (v) => setState(() => _vue = v),
                    ),
            ),
            Expanded(
              child: async.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => ErreurChargement(
                  message: '$e',
                  reessayer: () => ref.invalidate(donneesSaisonProvider),
                ),
                data: (d) => Column(
                  children: [
                    ChipsGroupes(
                      donnees: d,
                      filtre: _filtre,
                      onChange: (f) => setState(() => _filtre = f),
                      avant: BoutonCompetitions(
                        nombre: _filtre.nombreFiltresCompetition,
                        onTap: () async {
                          final choix = await choisirCompetitions(
                            context,
                            donnees: d,
                            filtre: _filtre,
                          );
                          if (choix != null) setState(() => _filtre = choix);
                        },
                      ),
                    ),
                    ChipsEquipes(
                      donnees: d,
                      filtre: _filtre,
                      onChange: (f) => setState(() => _filtre = f),
                    ),
                    Expanded(child: _liste(d, vue)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _liste(DonneesSaison d, String vue) {
    final toutes = d.filtrer(_filtre);
    // Les résultats remontent le temps, le programme va vers l'avant.
    final rencontres = vue == 'avenir'
        ? toutes.where((r) => r.programmee).toList().reversed.toList()
        : toutes.where((r) => r.jouee).toList();

    if (rencontres.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
        children: [
          CarteBlanche(
            enfant: Vide(
              message: vue == 'avenir'
                  ? 'Aucune rencontre programmée avec ces filtres.'
                  : 'Aucun résultat avec ces filtres.',
            ),
          ),
        ],
      );
    }

    final parMois = <String, List<Rencontre>>{};
    for (final r in rencontres) {
      parMois.putIfAbsent(moisEtAnnee(r.date), () => []).add(r);
    }

    return RefreshIndicator(
      color: Couleurs.bleu,
      onRefresh: () async {
        ref.invalidate(donneesSaisonProvider);
        await ref.read(donneesSaisonProvider.future);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 28),
        children: [
          for (final entree in parMois.entries)
            Section(
              titre: avecMajuscule(entree.key),
              enfant: CarteBlanche(
                enfant: Column(
                  children: [
                    for (var i = 0; i < entree.value.length; i++) ...[
                      if (i > 0) const Divider(height: 1),
                      if (vue == 'avenir')
                        LigneProgrammation(
                          rencontre: entree.value[i],
                          nomEquipe: d.nomEquipe(entree.value[i].equipeId),
                        )
                      else
                        LigneMatch(
                          onJoueur: (id) => JoueurPage.ouvrir(context, id),
                          rencontre: entree.value[i],
                          nomEquipe: d.nomEquipe(entree.value[i].equipeId),
                          buts: d.butsDe(entree.value[i].id),
                          tirsAuBut: d.tirsDe(entree.value[i].id),
                          joueurs: d.joueurs,
                        ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
