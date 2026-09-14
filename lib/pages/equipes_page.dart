import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/bilan_equipe.dart';
import '../models/equipe.dart';
import '../providers/club_providers.dart';
import '../providers/donnees_saison.dart';
import '../theme/app_theme.dart';
import '../widgets/communs.dart';
import '../widgets/entete.dart';
import 'perimetre_page.dart';

/// L'écran Équipes : les six groupes du club, chacun avec ses équipes,
/// leur forme récente et leur nombre de matchs joués.
///
/// C'est le premier écran de la refonte. Il valide toute la chaîne —
/// client Supabase, politiques de lecture anonyme, repository, providers,
/// affichage — sur un cas simple, avant qu'on en écrive dix autres.
class EquipesPage extends ConsumerWidget {
  const EquipesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final donnees = ref.watch(donneesEquipesProvider);

    return Scaffold(
      backgroundColor: Couleurs.craie,
      body: SafeArea(
        bottom: false,
        child: donnees.when(
          loading: () => const _Bandeau(
            titre: 'Équipes',
            sousTitre: 'Chargement…',
            corps: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => _Bandeau(
            titre: 'Équipes',
            sousTitre: 'La base est injoignable',
            corps: ErreurChargement(
              message: '$e',
              reessayer: () => ref.invalidate(donneesSaisonProvider),
            ),
          ),
          data: (d) => _Bandeau(
            titre: 'Équipes',
            sousTitre:
                '${d.nombreEquipes} équipes · saison ${d.saison.libelle}',
            selecteur: const SelecteurSaison(),
            corps: RefreshIndicator(
              color: Couleurs.bleu,
              onRefresh: () async {
                ref.invalidate(donneesSaisonProvider);
                await ref.read(donneesSaisonProvider.future);
              },
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
                itemCount: d.groupes.length,
                itemBuilder: (_, i) => _CarteGroupe(groupe: d.groupes[i]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Le bandeau bleu nuit, commun à tous les états de l'écran : il reste
/// affiché pendant le chargement et même en cas d'erreur, pour que
/// l'écran ne clignote pas d'un état à l'autre.
class _Bandeau extends StatelessWidget {
  const _Bandeau({
    required this.titre,
    required this.sousTitre,
    required this.corps,
    this.selecteur,
  });

  final String titre;
  final String sousTitre;
  final Widget corps;
  final Widget? selecteur;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          color: Couleurs.nuit,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titre,
                      style: Typo.titre(taille: 18, couleur: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      sousTitre,
                      style: Typo.texte(
                        taille: 11,
                        couleur: const Color(0xFF9DB0CE),
                      ),
                    ),
                  ],
                ),
              ),
              if (selecteur != null) selecteur!,
            ],
          ),
        ),
        Expanded(child: corps),
      ],
    );
  }
}

/// Un groupe : l'en-tête sombre de la catégorie, puis ses équipes.
class _CarteGroupe extends StatelessWidget {
  const _CarteGroupe({required this.groupe});

  final GroupeEquipes groupe;

  @override
  Widget build(BuildContext context) {
    final plusieurs = groupe.equipes.length > 1;

    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      decoration: AppTheme.carte,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // En-tête de catégorie
          Container(
            color: Couleurs.nuit,
            padding: const EdgeInsets.fromLTRB(13, 9, 13, 9),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        groupe.categorie.libelle,
                        style: Typo.titre(taille: 15, couleur: Colors.white),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${groupe.libelleGenre} · ${groupe.equipes.length} '
                        'équipe${plusieurs ? 's' : ''}',
                        style: Typo.texte(
                          taille: 10.5,
                          couleur: const Color(0xFF9DB0CE),
                        ),
                      ),
                    ],
                  ),
                ),
                if (plusieurs)
                  GestureDetector(
                    onTap: () => PerimetrePage.ouvrirCategorie(
                      context,
                      categorieId: groupe.categorie.id,
                      genre: groupe.genre,
                    ),
                    child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    padding: const EdgeInsets.fromLTRB(10, 4, 8, 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Vue catégorie',
                          style: Typo.texte(
                            taille: 11,
                            graisse: 700,
                            couleur: Colors.white,
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right,
                          size: 14,
                          color: Colors.white,
                        ),
                      ],
                    ),
                  ),
                  ),
              ],
            ),
          ),

          // Les équipes
          for (var i = 0; i < groupe.equipes.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            _LigneEquipe(
              equipe: groupe.equipes[i],
              bilan: groupe.bilanDe(groupe.equipes[i]),
            ),
          ],
        ],
      ),
    );
  }
}

class _LigneEquipe extends StatelessWidget {
  const _LigneEquipe({required this.equipe, required this.bilan});

  final Equipe equipe;
  final BilanEquipe bilan;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => PerimetrePage.ouvrirEquipe(context, equipe.id),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(13, 9, 13, 9),
        child: Row(
          children: [
            SizedBox(
              width: 78,
              child: Text(
                equipe.nom,
                style: Typo.texte(taille: 13, graisse: 700),
              ),
            ),
            Expanded(child: LigneDeForme(forme: bilan.forme)),
            Text(
              '${bilan.joues} match${bilan.joues > 1 ? 's' : ''}',
              style: Typo.texte(
                taille: 11.5,
                graisse: 600,
                couleur: Couleurs.bleu,
              ),
            ),
            const Icon(Icons.chevron_right, size: 15, color: Couleurs.bleu),
          ],
        ),
      ),
    );
  }
}

