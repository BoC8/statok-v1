import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/classement.dart';
import '../providers/club_providers.dart';
import '../providers/donnees_saison.dart';
import '../theme/app_theme.dart';
import '../widgets/classement_liste.dart';
import '../widgets/communs.dart';
import '../widgets/entete.dart';
import '../widgets/filtres.dart';
import '../widgets/ligne_match.dart';
import 'perimetre_page.dart';

/// L'accueil : ce qui arrive, ce qui vient de se passer, qui marque.
///
/// L'APPLICATION OUVRE SUR TOUT LE CLUB
///   Plus d'écran de choix de catégorie au lancement, plus de contexte
///   mémorisé dans les préférences. Un parent qui a deux enfants dans
///   deux catégories n'a plus à changer de mode pour voir les deux.
///   La catégorie est devenue une puce, pas une porte d'entrée.
class AccueilPage extends ConsumerStatefulWidget {
  const AccueilPage({super.key, this.onAllerAuxMatchs, this.onAllerAuxStats});

  /// L'accueil renvoie vers les autres onglets plutôt que d'empiler un
  /// écran : c'est la coquille qui sait basculer.
  final VoidCallback? onAllerAuxMatchs;
  final VoidCallback? onAllerAuxStats;

  @override
  ConsumerState<AccueilPage> createState() => _AccueilPageState();
}

class _AccueilPageState extends ConsumerState<AccueilPage> {
  FiltreClub _filtre = const FiltreClub();

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(donneesSaisonProvider);
    final saison = ref.watch(saisonCouranteProvider).value;

    return Scaffold(
      backgroundColor: Couleurs.craie,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            EnteteClub(
              sousTitre: saison == null
                  ? 'Football Club de la Pierre Bleue'
                  : 'Saison ${saison.libelle}',
              selecteur: const SelecteurSaison(),
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
                      categories: d.categories,
                      filtre: _filtre,
                      onChange: (f) => setState(() => _filtre = f),
                    ),
                    Expanded(child: _corps(d)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _corps(DonneesSaison d) {
    final rencontres = d.filtrer(_filtre);
    final aVenir = rencontres.where((r) => r.programmee).toList().reversed
        .toList();
    final jouees = rencontres.where((r) => r.jouee).toList();
    final maintenant = DateTime.now();

    final buteurs = construireClassement(
      buts: d.butsFiltres(_filtre),
      joueurs: d.joueurs,
      type: TypeClassement.buteurs,
    );

    return RefreshIndicator(
      color: Couleurs.bleu,
      onRefresh: () async {
        ref.invalidate(donneesSaisonProvider);
        await ref.read(donneesSaisonProvider.future);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 28),
        children: [
          Section(
            titre: 'Prochain match',
            enfant: aVenir.isEmpty
                ? const CarteBlanche(
                    enfant: Vide(
                      message: 'Aucune rencontre programmée pour cette '
                          'sélection.',
                    ),
                  )
                : CarteProchainMatch(
                    rencontre: aVenir.first,
                    nomEquipe: d.nomEquipe(aVenir.first.equipeId),
                    maintenant: maintenant,
                  ),
          ),

          if (aVenir.length > 1)
            Section(
              titre: 'Aussi au programme',
              action: 'Tout voir',
              onAction: widget.onAllerAuxMatchs,
              enfant: CarteBlanche(
                enfant: _Liste(
                  enfants: [
                    for (final r in aVenir.skip(1).take(4))
                      LigneProgrammation(
                        rencontre: r,
                        nomEquipe: d.nomEquipe(r.equipeId),
                      ),
                  ],
                ),
              ),
            ),

          Section(
            titre: 'Derniers résultats',
            action: jouees.isEmpty ? null : 'Tout voir',
            onAction: widget.onAllerAuxMatchs,
            enfant: CarteBlanche(
              enfant: jouees.isEmpty
                  ? const Vide(message: 'Aucun match joué pour le moment.')
                  : _Liste(
                      enfants: [
                        for (final r in jouees.take(4))
                          LigneMatch(
                            rencontre: r,
                            nomEquipe: d.nomEquipe(r.equipeId),
                            buts: d.butsDe(r.id),
                            tirsAuBut: d.tirsDe(r.id),
                            joueurs: d.joueurs,
                          ),
                      ],
                    ),
            ),
          ),

          Section(
            titre: 'Meilleurs buteurs',
            action: buteurs.isEmpty ? null : 'Classements',
            onAction: widget.onAllerAuxStats,
            enfant: ClassementListe(
              lignes: buteurs.take(3).toList(),
              type: TypeClassement.buteurs,
              messageVide: 'Aucun but enregistré pour cette sélection.',
            ),
          ),

          Section(
            titre: 'Catégories',
            enfant: CarteBlanche(
              enfant: _Liste(
                enfants: [
                  for (final c in d.categories)
                    for (final genre in const ['M', 'F'])
                      if (d.equipesDuGroupe(c.id, genre).isNotEmpty)
                        _LigneCategorie(
                          libelle:
                              '${c.libelle} · '
                              '${genre == 'F' ? 'Féminines' : 'Masculins'}',
                          equipes: d
                              .equipesDuGroupe(c.id, genre)
                              .map((e) => e.nom)
                              .join(' · '),
                          onTap: () => PerimetrePage.ouvrirCategorie(
                            context,
                            categorieId: c.id,
                            genre: genre,
                          ),
                        ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Une colonne d'éléments séparés par un filet, sans filet aux extrémités.
class _Liste extends StatelessWidget {
  const _Liste({required this.enfants});

  final List<Widget> enfants;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < enfants.length; i++) ...[
          if (i > 0) const Divider(height: 1),
          enfants[i],
        ],
      ],
    );
  }
}

class _LigneCategorie extends StatelessWidget {
  const _LigneCategorie({
    required this.libelle,
    required this.equipes,
    required this.onTap,
  });

  final String libelle;
  final String equipes;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(13, 9, 13, 9),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(libelle, style: Typo.texte(taille: 13, graisse: 600)),
                  const SizedBox(height: 3),
                  Text(
                    equipes,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Typo.texte(taille: 10.5, couleur: Couleurs.gris),
                  ),
                ],
              ),
            ),
            Text(
              'Voir',
              style: Typo.texte(
                taille: 11.5,
                graisse: 700,
                couleur: Couleurs.bleu,
              ),
            ),
            const Icon(Icons.chevron_right, size: 14, color: Couleurs.bleu),
          ],
        ),
      ),
    );
  }
}
