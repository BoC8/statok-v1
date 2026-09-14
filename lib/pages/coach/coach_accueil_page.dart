import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/profil.dart';
import '../../models/rencontre.dart';
import '../../providers/auth_providers.dart';
import '../../providers/club_providers.dart';
import '../../providers/donnees_saison.dart';
import '../../theme/app_theme.dart';
import '../../widgets/communs.dart';
import '../../widgets/entete.dart';
import 'form_rencontre_page.dart';

/// L'accueil du staff : ce qu'il y a à saisir, et l'accès aux listes.
///
/// CE QU'IL Y A À FAIRE, PAS CE QU'IL Y A À VOIR
///   Un coach ouvre cet écran le dimanche soir pour saisir un résultat.
///   La première chose qu'il doit trouver, c'est la liste des matchs
///   joués dont le score manque encore — pas un tableau de bord.
class CoachAccueilPage extends ConsumerWidget {
  const CoachAccueilPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profil = ref.watch(profilProvider).value;
    final donnees = ref.watch(donneesSaisonProvider).value;
    final equipes = ref.watch(equipesModifiablesProvider).value ?? const [];
    final saison = ref.watch(saisonCouranteProvider).value;
    final active = ref.watch(saisonActiveProvider).value;
    final horsSaison =
        saison != null && active != null && saison.id != active.id;

    if (profil == null || donnees == null) {
      return const Scaffold(
        backgroundColor: Couleurs.craie,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final miennes = equipes.map((e) => e.id).toSet();
    final aSaisir = _aSaisir(donnees, miennes);
    final prochaines = donnees.rencontres
        .where((r) => r.programmee && miennes.contains(r.equipeId))
        .toList()
        .reversed
        .toList();

    return Scaffold(
      backgroundColor: Couleurs.craie,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            EnteteSimple(
              titre: 'Espace coachs',
              sousTitre: _sousTitre(profil, equipes.length, saison?.libelle),
              selecteur: IconButton(
                tooltip: 'Se déconnecter',
                onPressed: () async {
                  await ref.read(adminRepositoryProvider).deconnexion();
                  ref.invalidate(profilProvider);
                },
                icon: const Icon(Icons.logout, size: 18),
                color: Colors.white,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                  minimumSize: const Size(34, 34),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11),
                  ),
                ),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                color: Couleurs.bleu,
                onRefresh: () async {
                  ref.invalidate(donneesSaisonProvider);
                  await ref.read(donneesSaisonProvider.future);
                },
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 28),
                  children: [
                    // On consulte une saison archivée : le dire, et
                    // proposer de revenir. Sans cet avertissement, un
                    // coach verrait une liste vide sans comprendre
                    // pourquoi ses équipes ont disparu.
                    if (horsSaison)
                      Section(
                        titre: 'Saison consultée',
                        enfant: _BandeauArchive(
                          libelle: saison.libelle,
                          active: active.libelle,
                          onRevenir: () => ref
                              .read(saisonChoisieProvider.notifier)
                              .state = active.id,
                        ),
                      ),
                    if (equipes.isEmpty)
                      const Section(
                        titre: 'Habilitation manquante',
                        enfant: CarteBlanche(
                          enfant: Vide(
                            message:
                                "Votre compte n'est rattaché à aucune "
                                'catégorie. Demandez à un administrateur du '
                                'club de vous en attribuer une : sans cela '
                                'vous ne pouvez rien enregistrer.',
                          ),
                        ),
                      )
                    else ...[
                      Section(
                        titre: 'Saisir',
                        enfant: SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: Couleurs.bleu,
                              padding: const EdgeInsets.symmetric(
                                vertical: 14,
                              ),
                            ),
                            onPressed: () =>
                                FormRencontrePage.ouvrir(context),
                            icon: const Icon(Icons.add, size: 18),
                            label: Text(
                              'Nouvelle rencontre',
                              style: Typo.texte(
                                taille: 14,
                                graisse: 700,
                                couleur: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),

                      if (aSaisir.isNotEmpty)
                        Section(
                          titre: 'Résultats à compléter',
                          enfant: CarteBlanche(
                            enfant: Column(
                              children: [
                                for (var i = 0; i < aSaisir.length; i++) ...[
                                  if (i > 0) const Divider(height: 1),
                                  _LigneASaisir(
                                    rencontre: aSaisir[i],
                                    nomEquipe: donnees.nomEquipe(
                                      aSaisir[i].equipeId,
                                    ),
                                    alerte: true,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),

                      Section(
                        titre: 'Rencontres à venir',
                        enfant: CarteBlanche(
                          enfant: prochaines.isEmpty
                              ? const Vide(
                                  message:
                                      'Rien de programmé sur vos catégories.',
                                )
                              : Column(
                                  children: [
                                    for (
                                      var i = 0;
                                      i < prochaines.take(6).length;
                                      i++
                                    ) ...[
                                      if (i > 0) const Divider(height: 1),
                                      _LigneASaisir(
                                        rencontre: prochaines[i],
                                        nomEquipe: donnees.nomEquipe(
                                          prochaines[i].equipeId,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                        ),
                      ),

                      Section(
                        titre: 'Bon à savoir',
                        enfant: CarteBlanche(
                          enfant: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Text(
                              'Les classements se calculent tout seuls à '
                              'partir des buts saisis. Pensez à renseigner '
                              'les passeurs : sans eux, le classement des '
                              'passes décisives reste vide.\n\n'
                              'Une rencontre se saisit une seule fois : on '
                              'la programme, puis on revient y ajouter le '
                              'score après le match.',
                              style: Typo.texte(
                                taille: 12,
                                couleur: Couleurs.gris,
                                hauteurLigne: 1.6,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _sousTitre(Profil profil, int nbEquipes, String? saison) {
    final morceaux = <String>[profil.nom.isEmpty ? 'Staff' : profil.nom];
    morceaux.add(
      profil.estAdmin
          ? 'administrateur'
          : '$nbEquipes équipe${nbEquipes > 1 ? 's' : ''}',
    );
    if (saison != null) morceaux.add('saison $saison');
    return morceaux.join(' · ');
  }

  /// Les rencontres passées qui n'ont pas encore de score.
  ///
  /// C'est le vrai travail en attente : un match dont la date est
  /// dépassée mais qui est toujours marqué « à venir ».
  List<Rencontre> _aSaisir(DonneesSaison d, Set<String> miennes) {
    final maintenant = DateTime.now();
    return d.rencontres
        .where(
          (r) =>
              r.programmee &&
              miennes.contains(r.equipeId) &&
              r.date.isBefore(maintenant),
        )
        .toList();
  }
}

class _LigneASaisir extends ConsumerWidget {
  const _LigneASaisir({
    required this.rencontre,
    required this.nomEquipe,
    this.alerte = false,
  });

  final Rencontre rencontre;
  final String nomEquipe;
  final bool alerte;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: () =>
          FormRencontrePage.ouvrir(context, rencontre: rencontre),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
        child: Row(
          children: [
            if (alerte)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(right: 10),
                decoration: const BoxDecoration(
                  color: Couleurs.or,
                  shape: BoxShape.circle,
                ),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$nomEquipe — ${rencontre.adversaire}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Typo.texte(taille: 13, graisse: 600),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${avecMajuscule(dateLongue(rencontre.date))} · '
                    '${heureDe(rencontre.date)} · '
                    '${rencontre.domicile ? 'domicile' : 'extérieur'} · '
                    '${rencontre.libelleCompetition}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Typo.texte(taille: 10.5, couleur: Couleurs.gris),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 16, color: Couleurs.gris2),
          ],
        ),
      ),
    );
  }
}


/// L'avertissement affiché quand le staff consulte une saison passée.
class _BandeauArchive extends StatelessWidget {
  const _BandeauArchive({
    required this.libelle,
    required this.active,
    required this.onRevenir,
  });

  final String libelle;
  final String active;
  final VoidCallback onRevenir;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
      decoration: BoxDecoration(
        color: Couleurs.orClair,
        border: Border.all(color: const Color(0xFFF3DFAE)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.history,
            size: 18,
            color: Couleurs.or,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Vous consultez la saison $libelle, terminée. Les listes '
                  "ci-dessous n'affichent que ses rencontres.",
                  style: Typo.texte(
                    taille: 12,
                    couleur: const Color(0xFF7A4F00),
                    hauteurLigne: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: onRevenir,
                  child: Text(
                    'Revenir à $active',
                    style: Typo.texte(
                      taille: 12.5,
                      graisse: 700,
                      couleur: Couleurs.bleu,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
