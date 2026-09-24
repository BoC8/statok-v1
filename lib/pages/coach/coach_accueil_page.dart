import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/equipe.dart';
import '../../models/profil.dart';
import '../../models/rencontre.dart';
import '../../providers/auth_providers.dart';
import '../../providers/club_providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/communs.dart';
import '../../widgets/entete.dart';
import 'form_rencontre_page.dart';
import 'joueurs_admin_page.dart';
import 'parametres_page.dart';
import 'rencontres_admin_page.dart';
import 'structure_page.dart';

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
    // La saison de TRAVAIL, pas celle que le sélecteur public affiche :
    // la saison en cours pour un coach, la saison consultée pour un
    // administrateur. Voir `saisonAtelierProvider`.
    final saison = ref.watch(saisonAtelierProvider).value;
    final rencontres = ref.watch(rencontresAtelierProvider).value;
    final equipes = saison == null
        ? const <Equipe>[]
        : ref.watch(equipesModifiablesProvider(saison.id)).value ?? const [];
    final active = ref.watch(saisonActiveProvider).value;
    // Un coach ne peut pas être hors saison : son atelier EST la saison
    // en cours. Ce bandeau ne peut donc apparaître que pour un admin.
    final horsSaison =
        saison != null && active != null && saison.id != active.id;

    if (profil == null || saison == null || rencontres == null) {
      return const Scaffold(
        backgroundColor: Couleurs.craie,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final miennes = equipes.map((e) => e.id).toSet();
    final aSaisir = _aSaisir(rencontres, miennes);
    final programmees = rencontres
        .where((r) => r.programmee && miennes.contains(r.equipeId))
        .length;

    return Scaffold(
      backgroundColor: Couleurs.craie,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            EnteteSimple(
              titre: 'Espace coachs',
              sousTitre: _sousTitre(profil, equipes.length, saison.libelle),
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
                  ref.invalidate(rencontresAtelierProvider);
                  await ref.read(rencontresAtelierProvider.future);
                },
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 28),
                  children: [
                    // Un administrateur est en train de corriger une
                    // saison terminée : le dire franchement, et lui
                    // offrir le retour. Sans cet avertissement, il
                    // saisirait le match de dimanche dans la mauvaise
                    // année en croyant être chez lui.
                    if (horsSaison)
                      Section(
                        titre: 'Saison de travail',
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

                      Section(
                        titre: 'Gérer',
                        enfant: CarteBlanche(
                          enfant: Column(
                            children: [
                              _Raccourci(
                                icone: Icons.event_note_outlined,
                                titre: 'Rencontres',
                                sousTitre: _etatRencontres(
                                  aSaisir.length,
                                  programmees,
                                ),
                                pastille: aSaisir.isEmpty
                                    ? null
                                    : '${aSaisir.length}',
                                onTap: () =>
                                    RencontresAdminPage.ouvrir(context),
                              ),
                              const Divider(height: 1),
                              _Raccourci(
                                icone: Icons.badge_outlined,
                                titre: 'Licenciés',
                                sousTitre:
                                    'Ajouter, corriger un nom, retirer de '
                                    "l'effectif",
                                onTap: () => JoueursAdminPage.ouvrir(context),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],

                    // LES FONDATIONS, HORS DU `else`
                    //
                    //   Réservées au super administrateur — et pas
                    //   seulement ici : les politiques RLS refusent ces
                    //   écritures à tout autre compte. Masquer l'entrée
                    //   évite d'ouvrir un écran qui finirait en message
                    //   d'erreur, rien de plus.
                    //
                    //   Cette section est volontairement en dehors du
                    //   bloc « si le compte a des équipes ». Sur un club
                    //   vierge il n'y en a aucune, et c'est précisément
                    //   par cet écran qu'on en crée : l'enfermer dans le
                    //   `else` en ferait un cul-de-sac.
                    if (profil.estSuperAdmin)
                      Section(
                        titre: 'Administrer',
                        enfant: CarteBlanche(
                          enfant: Column(
                            children: [
                              _Raccourci(
                                icone: Icons.account_tree_outlined,
                                titre: 'Catégories et équipes',
                                sousTitre:
                                    'La structure du club et les '
                                    'compétitions de chaque équipe',
                                onTap: () => StructurePage.ouvrir(context),
                              ),
                              const Divider(height: 1),
                              _Raccourci(
                                icone: Icons.tune,
                                titre: 'Paramètres',
                                sousTitre:
                                    'Le texte ci-dessous, et la montée de '
                                    'catégorie',
                                onTap: () => ParametresPage.ouvrir(context),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Le texte vient de la base : le super administrateur
                    // le réécrit depuis Paramètres, sans qu'on reprenne le
                    // code ni qu'on republie l'application.
                    Section(
                      titre: 'Bon à savoir',
                      enfant: CarteBlanche(
                        enfant: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Text(
                            ref.watch(bonASavoirProvider),
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
    morceaux.add(switch (profil.role) {
      'super_admin' => 'super administrateur',
      'admin' => 'administrateur',
      _ => '$nbEquipes équipe${nbEquipes > 1 ? 's' : ''}',
    });
    if (saison != null) morceaux.add('saison $saison');
    return morceaux.join(' · ');
  }

  /// Les rencontres passées qui n'ont toujours pas de score.
  ///
  /// C'est le vrai travail en attente : un match dont la date est
  /// dépassée mais qui est resté marqué « à venir ». On n'en dresse plus
  /// la liste ici — elle faisait double emploi avec l'écran Rencontres —
  /// mais on en garde le compte, parce que c'est la seule chose que le
  /// coach doit savoir en ouvrant l'application.
  List<Rencontre> _aSaisir(List<Rencontre> rencontres, Set<String> miennes) {
    final maintenant = DateTime.now();
    return rencontres
        .where(
          (r) =>
              miennes.contains(r.equipeId) && r.aSaisir(maintenant),
        )
        .toList();
  }

  String _etatRencontres(int aSaisir, int programmees) {
    if (aSaisir > 0) {
      return aSaisir == 1
          ? 'Un score attend encore sa saisie'
          : '$aSaisir scores attendent encore leur saisie';
    }
    if (programmees > 0) {
      return programmees == 1
          ? 'Une rencontre programmée, à jour'
          : '$programmees rencontres programmées, tout est à jour';
    }
    return 'Programmer un match, corriger un résultat';
  }
}

/// L'avertissement affiché quand un administrateur travaille sur une
/// saison terminée. Un coach ne le verra jamais : il n'écrit que sur la
/// saison en cours.
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
                  'Vous travaillez sur la saison $libelle, terminée. Tout '
                  'ce que vous enregistrez ici y sera rattaché.',
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


/// Une entrée du menu de gestion.
class _Raccourci extends StatelessWidget {
  const _Raccourci({
    required this.icone,
    required this.titre,
    required this.sousTitre,
    required this.onTap,
    this.pastille,
  });

  final IconData icone;
  final String titre;
  final String sousTitre;
  final VoidCallback onTap;

  /// Le nombre affiché en orange à droite : ce qui reste à faire.
  final String? pastille;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Couleurs.bleuClair,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icone, size: 18, color: Couleurs.bleu),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titre, style: Typo.texte(taille: 13, graisse: 700)),
                  const SizedBox(height: 3),
                  Text(
                    sousTitre,
                    style: Typo.texte(taille: 10.5, couleur: Couleurs.gris),
                  ),
                ],
              ),
            ),
            if (pastille != null)
              Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: Couleurs.orClair,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  pastille!,
                  style: Typo.chiffres(
                    taille: 12,
                    graisse: 700,
                    couleur: const Color(0xFF7A4F00),
                  ),
                ),
              ),
            const Icon(Icons.chevron_right, size: 16, color: Couleurs.gris2),
          ],
        ),
      ),
    );
  }
}
