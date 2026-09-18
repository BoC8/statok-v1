import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/categorie.dart';
import '../../models/equipe.dart';
import '../../models/generations.dart';
import '../../providers/auth_providers.dart';
import '../../providers/club_providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/communs.dart';
import 'engagements_page.dart';
import 'form_categorie_page.dart';
import 'form_equipe_page.dart';

/// Les fondations du club — réservé au super administrateur.
///
/// LES DEUX NIVEAUX SONT SUR LE MÊME ÉCRAN
///   Une catégorie sans ses équipes ne veut rien dire, et une équipe se
///   crée toujours dans une catégorie. Les séparer en deux entrées de
///   menu obligerait à faire des allers-retours pour comprendre ce qu'on
///   est en train de changer. Un segment suffit à basculer.
class StructurePage extends ConsumerStatefulWidget {
  const StructurePage({super.key});

  static Future<void> ouvrir(BuildContext context) => Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => const StructurePage()));

  @override
  ConsumerState<StructurePage> createState() => _StructurePageState();
}

class _StructurePageState extends ConsumerState<StructurePage> {
  String _vue = 'equipes';
  bool _avecDissoutes = false;

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider).value;
    final equipes = ref.watch(toutesLesEquipesProvider).value;
    final saison = ref.watch(saisonAtelierProvider).value;

    if (categories == null || equipes == null || saison == null) {
      return const Scaffold(
        backgroundColor: Couleurs.craie,
        body: SafeArea(
          child: Column(
            children: [
              BandeauRetour(titre: 'Catégories et équipes'),
              Expanded(child: Center(child: CircularProgressIndicator())),
            ],
          ),
        ),
      );
    }

    final dissoutes = equipes.where((e) => !e.actif).length;

    return Scaffold(
      backgroundColor: Couleurs.craie,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            BandeauRetour(
              titre: 'Catégories et équipes',
              sousTitre:
                  '${categories.length} catégories · '
                  '${equipes.where((e) => e.actif).length} équipes · '
                  'saison ${saison.libelle}',
              action: IconButton(
                tooltip: _vue == 'equipes'
                    ? 'Nouvelle équipe'
                    : 'Nouvelle catégorie',
                onPressed: () async {
                  if (_vue == 'equipes') {
                    await FormEquipePage.ouvrir(context);
                  } else {
                    await FormCategoriePage.ouvrir(context);
                  }
                  if (context.mounted) rafraichirApresStructure(ref);
                },
                icon: const Icon(Icons.add, color: Colors.white),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                  minimumSize: const Size(34, 34),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11),
                  ),
                ),
              ),
            ),
            Container(
              decoration: const BoxDecoration(
                color: Couleurs.blanc,
                border: Border(bottom: BorderSide(color: Couleurs.ligne)),
              ),
              padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
              child: Segments(
                options: const [
                  ('equipes', 'Équipes'),
                  ('categories', 'Catégories'),
                ],
                actif: _vue,
                onChoix: (v) => setState(() => _vue = v),
              ),
            ),
            if (_vue == 'equipes' && dissoutes > 0)
              Container(
                decoration: const BoxDecoration(
                  color: Couleurs.blanc,
                  border: Border(bottom: BorderSide(color: Couleurs.ligne)),
                ),
                padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: PuceFiltre(
                    libelle: 'Avec les équipes dissoutes ($dissoutes)',
                    choisi: _avecDissoutes,
                    onTap: () =>
                        setState(() => _avecDissoutes = !_avecDissoutes),
                  ),
                ),
              ),
            Expanded(
              child: _vue == 'equipes'
                  ? _listeEquipes(categories, equipes, saison.libelle)
                  : _listeCategories(categories, equipes),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------------
  //  Les équipes, groupées comme partout ailleurs
  // -------------------------------------------------------------------

  Widget _listeEquipes(
    List<Categorie> categories,
    List<Equipe> equipes,
    String libelleSaison,
  ) {
    final visibles = equipes.where((e) => _avecDissoutes || e.actif).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 28),
      children: [
        for (final c in categories)
          for (final genre in const ['M', 'F'])
            if (visibles.any((e) => e.categorieId == c.id && e.genre == genre))
              Section(
                titre: '${c.libelle} · '
                    '${genre == 'F' ? 'Féminines' : 'Masculins'}',
                enfant: CarteBlanche(
                  enfant: Column(
                    children: [
                      for (final (i, e) in _duGroupe(
                        visibles,
                        c.id,
                        genre,
                      ).indexed) ...[
                        if (i > 0) const Divider(height: 1),
                        _LigneEquipe(
                          equipe: e,
                          onModifier: () async {
                            await FormEquipePage.ouvrir(context, equipe: e);
                            if (context.mounted) rafraichirApresStructure(ref);
                          },
                          onCompetitions: () async {
                            await EngagementsPage.ouvrir(context, equipe: e);
                            if (context.mounted) rafraichirApresStructure(ref);
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
        Padding(
          padding: const EdgeInsets.only(top: 20),
          child: Text(
            "Les compétitions se règlent équipe par équipe, pour la saison "
            '$libelleSaison : touchez l’icône de coupe à droite d’une '
            'équipe.',
            style: Typo.texte(
              taille: 11.5,
              couleur: Couleurs.gris2,
              hauteurLigne: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  List<Equipe> _duGroupe(List<Equipe> equipes, String categorieId, String g) {
    return equipes
        .where((e) => e.categorieId == categorieId && e.genre == g)
        .toList()
      ..sort((a, b) => a.ordre.compareTo(b.ordre));
  }

  // -------------------------------------------------------------------
  //  Les catégories
  // -------------------------------------------------------------------

  Widget _listeCategories(List<Categorie> categories, List<Equipe> equipes) {
    // Une génération revendiquée par deux catégories rendrait le
    // rattachement d'un licencié arbitraire — et les droits des coachs
    // avec. On la signale avant qu'elle ne fasse des dégâts.
    final compte = <String, int>{};
    for (final c in categories) {
      for (final g in c.generations) {
        compte[g] = (compte[g] ?? 0) + 1;
      }
    }
    final doublons = compte.entries.where((e) => e.value > 1).map((e) => e.key);
    final orphelines = generationsOrdonnees
        .where((g) => !compte.containsKey(g))
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 28),
      children: [
        if (doublons.isNotEmpty)
          Section(
            titre: 'À corriger',
            enfant: _Alerte(
              texte:
                  'Ces générations appartiennent à deux catégories : '
                  '${doublons.map(libelleGeneration).join(', ')}. Un '
                  "licencié de cet âge sera rattaché à l'une ou à l'autre "
                  'sans règle, et les droits de ses coachs deviennent '
                  'imprévisibles.',
            ),
          ),
        Section(
          titre: 'Les catégories du club',
          enfant: CarteBlanche(
            enfant: Column(
              children: [
                for (final (i, c) in categories.indexed) ...[
                  if (i > 0) const Divider(height: 1),
                  _LigneCategorie(
                    categorie: c,
                    nbEquipes: equipes
                        .where((e) => e.categorieId == c.id && e.actif)
                        .length,
                    onModifier: () async {
                      await FormCategoriePage.ouvrir(context, categorie: c);
                      if (context.mounted) rafraichirApresStructure(ref);
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
        if (orphelines.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 20),
            child: Text(
              'Générations sans catégorie : '
              '${orphelines.map(libelleGeneration).join(', ')}. Un licencié '
              "de cet âge existe, mais aucun coach n'a de droits sur lui — "
              'seul un administrateur pourra modifier sa fiche.',
              style: Typo.texte(
                taille: 11.5,
                couleur: Couleurs.gris2,
                hauteurLigne: 1.5,
              ),
            ),
          ),
      ],
    );
  }
}

class _LigneEquipe extends StatelessWidget {
  const _LigneEquipe({
    required this.equipe,
    required this.onModifier,
    required this.onCompetitions,
  });

  final Equipe equipe;
  final VoidCallback onModifier;
  final VoidCallback onCompetitions;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onModifier,
      child: Opacity(
        opacity: equipe.actif ? 1 : 0.6,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(13, 9, 6, 9),
          child: Row(
            children: [
              SizedBox(
                width: 22,
                child: Text(
                  '${equipe.ordre}',
                  style: Typo.chiffres(taille: 13, couleur: Couleurs.gris2),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      equipe.nom,
                      style: Typo.texte(taille: 13, graisse: 600),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      equipe.actif
                          ? 'jusqu’à ${libelleGeneration(equipe.generationMax)}'
                          : 'dissoute · jusqu’à '
                                '${libelleGeneration(equipe.generationMax)}',
                      style: Typo.texte(taille: 10.5, couleur: Couleurs.gris),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Compétitions de cette équipe',
                onPressed: onCompetitions,
                icon: const Icon(
                  Icons.emoji_events_outlined,
                  size: 19,
                  color: Couleurs.bleu,
                ),
              ),
              const Icon(
                Icons.chevron_right,
                size: 16,
                color: Couleurs.gris2,
              ),
              const SizedBox(width: 6),
            ],
          ),
        ),
      ),
    );
  }
}

class _LigneCategorie extends StatelessWidget {
  const _LigneCategorie({
    required this.categorie,
    required this.nbEquipes,
    required this.onModifier,
  });

  final Categorie categorie;
  final int nbEquipes;
  final VoidCallback onModifier;

  @override
  Widget build(BuildContext context) {
    final rangees = [...categorie.generations]
      ..sort((a, b) => rangGeneration(a).compareTo(rangGeneration(b)));

    return InkWell(
      onTap: onModifier,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    categorie.libelle,
                    style: Typo.texte(taille: 13, graisse: 600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${rangees.map(libelleGeneration).join(' · ')}'
                    '${nbEquipes > 0 ? '  —  $nbEquipes équipe${nbEquipes > 1 ? 's' : ''}' : '  —  aucune équipe'}',
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

class _Alerte extends StatelessWidget {
  const _Alerte({required this.texte});

  final String texte;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      decoration: BoxDecoration(
        color: Couleurs.orClair,
        border: Border.all(color: const Color(0xFFF3DFAE)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        texte,
        style: Typo.texte(
          taille: 12,
          couleur: const Color(0xFF7A4F00),
          hauteurLigne: 1.5,
        ),
      ),
    );
  }
}
