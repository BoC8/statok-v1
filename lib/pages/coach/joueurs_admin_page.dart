import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/categorie.dart';
import '../../models/generations.dart';
import '../../models/joueur.dart';
import '../../providers/auth_providers.dart';
import '../../providers/club_providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/communs.dart';
import 'form_joueur_page.dart';

/// L'effectif.
///
/// CHACUN NE VOIT QUE CE QU'IL PEUT TOUCHER
///   Un coach ne voit que les licenciés de sa catégorie — ceux dont il
///   répond. Montrer les autres en grisé, comme le faisait la première
///   version, ne lui apprenait rien d'utile : il ne pouvait ni les
///   corriger ni les supprimer, et la liste du club entier noyait la
///   sienne.
///
///   L'administrateur, lui, voit tout le monde, et a besoin de s'y
///   retrouver : il filtre d'abord par catégorie principale, puis par
///   génération à l'intérieur, puis par genre. Les trois rangées ne lui
///   sont montrées que si elles servent à quelque chose.
class JoueursAdminPage extends ConsumerStatefulWidget {
  const JoueursAdminPage({super.key});

  static Future<void> ouvrir(BuildContext context) => Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => const JoueursAdminPage()));

  @override
  ConsumerState<JoueursAdminPage> createState() => _JoueursAdminPageState();
}

class _JoueursAdminPageState extends ConsumerState<JoueursAdminPage> {
  String _recherche = '';

  /// `null` = toutes les catégories principales.
  String? _categorieId;

  /// `null` = toutes les générations.
  String? _generation;

  /// `'tout'`, `'M'` ou `'F'`.
  String _genre = 'tout';

  bool _avecInactifs = false;

  @override
  Widget build(BuildContext context) {
    final profil = ref.watch(profilProvider).value;
    final categories = ref.watch(categoriesProvider).value;
    final tous = ref.watch(tousLesJoueursProvider).value;

    if (profil == null || categories == null || tous == null) {
      return const Scaffold(
        backgroundColor: Couleurs.craie,
        body: SafeArea(
          child: Column(
            children: [
              BandeauRetour(titre: 'Licenciés'),
              Expanded(child: Center(child: CircularProgressIndicator())),
            ],
          ),
        ),
      );
    }

    // Le périmètre : tout le club pour un admin, ses seules catégories
    // pour un coach. C'est la même règle que celle de la base — voir
    // `Profil.peutEcrireJoueur`.
    final miens = tous
        .where((j) => profil.peutEcrireJoueur(j, categories))
        .toList();

    // Les catégories qui comptent réellement quelqu'un : un filtre qui
    // ne ramène personne n'a pas à être proposé.
    final categoriesUtiles = [
      for (final c in categories)
        if (miens.any((j) => c.accueille(j.generation))) c,
    ]..sort((a, b) => a.ordre.compareTo(b.ordre));

    // Un choix de catégorie devenu impossible (l'admin a masqué les
    // partis, et la catégorie s'est vidée) ne doit pas figer la liste.
    if (_categorieId != null &&
        !categoriesUtiles.any((c) => c.id == _categorieId)) {
      _categorieId = null;
    }

    final categorieChoisie = _categorieId == null
        ? null
        : categoriesUtiles.firstWhere((c) => c.id == _categorieId);

    // Les générations proposées suivent la catégorie retenue.
    final generationsUtiles = <String>[
      for (final g in generationsOrdonnees)
        if (miens.any(
              (j) =>
                  j.generation == g && (_avecInactifs || j.actif),
            ) &&
            (categorieChoisie == null || categorieChoisie.accueille(g)))
          g,
    ];
    if (_generation != null && !generationsUtiles.contains(_generation)) {
      _generation = null;
    }

    final avecDeuxGenres =
        miens.any((j) => j.genre == 'M') && miens.any((j) => j.genre == 'F');
    if (!avecDeuxGenres) _genre = 'tout';

    final terme = _recherche.trim().toLowerCase();
    final liste =
        miens
            .where((j) => _avecInactifs || j.actif)
            .where(
              (j) =>
                  categorieChoisie == null ||
                  categorieChoisie.accueille(j.generation),
            )
            .where((j) => _generation == null || j.generation == _generation)
            .where((j) => _genre == 'tout' || j.genre == _genre)
            .where(
              (j) => terme.isEmpty || j.nomComplet.toLowerCase().contains(terme),
            )
            .toList()
          ..sort((a, b) {
            final parGeneration = rangGeneration(
              a.generation,
            ).compareTo(rangGeneration(b.generation));
            if (parGeneration != 0) return parGeneration;
            return a.nom.toLowerCase().compareTo(b.nom.toLowerCase());
          });

    final inactifs = miens.where((j) => !j.actif).length;

    return Scaffold(
      backgroundColor: Couleurs.craie,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            BandeauRetour(
              titre: 'Licenciés',
              sousTitre:
                  '${liste.length} fiche${liste.length > 1 ? 's' : ''}'
                  '${inactifs > 0 && !_avecInactifs ? ' · $inactifs hors effectif' : ''}',
              action: IconButton(
                tooltip: 'Nouveau licencié',
                onPressed: () async {
                  await FormJoueurPage.ouvrir(context);
                  ref.invalidate(tousLesJoueursProvider);
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

            _Barre(
              enfant: TextField(
                onChanged: (v) => setState(() => _recherche = v),
                style: Typo.texte(taille: 14),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Rechercher un licencié',
                  hintStyle: Typo.texte(taille: 13.5, couleur: Couleurs.gris2),
                  prefixIcon: const Icon(
                    Icons.search,
                    size: 19,
                    color: Couleurs.gris2,
                  ),
                  filled: true,
                  fillColor: Couleurs.craie,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(11),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            // Rangée 1 — les catégories principales. Inutile à un coach
            // qui n'en a qu'une.
            if (categoriesUtiles.length > 1)
              _Rangee(
                children: [
                  PuceFiltre(
                    libelle: 'Toutes catégories',
                    choisi: _categorieId == null,
                    onTap: () => setState(() {
                      _categorieId = null;
                      _generation = null;
                    }),
                  ),
                  for (final c in categoriesUtiles)
                    PuceFiltre(
                      libelle: c.libelle,
                      choisi: _categorieId == c.id,
                      onTap: () => setState(() {
                        _categorieId = c.id;
                        _generation = null;
                      }),
                    ),
                ],
              ),

            // Rangée 2 — les générations, à l'intérieur de la catégorie.
            if (generationsUtiles.length > 1)
              _Rangee(
                children: [
                  PuceFiltre(
                    libelle: 'Toutes générations',
                    choisi: _generation == null,
                    onTap: () => setState(() => _generation = null),
                  ),
                  for (final g in generationsUtiles)
                    PuceFiltre(
                      libelle: libelleGeneration(g),
                      choisi: _generation == g,
                      onTap: () => setState(() => _generation = g),
                    ),
                  if (inactifs > 0)
                    PuceFiltre(
                      libelle: 'Avec les partis',
                      choisi: _avecInactifs,
                      onTap: () =>
                          setState(() => _avecInactifs = !_avecInactifs),
                    ),
                ],
              )
            else if (inactifs > 0)
              _Rangee(
                children: [
                  PuceFiltre(
                    libelle: 'Avec les partis',
                    choisi: _avecInactifs,
                    onTap: () => setState(() => _avecInactifs = !_avecInactifs),
                  ),
                ],
              ),

            // Rangée 3 — le genre, seulement si le périmètre en compte
            // deux.
            if (avecDeuxGenres)
              _Barre(
                enfant: Segments(
                  options: const [
                    ('tout', 'Tous'),
                    ('M', 'Masculins'),
                    ('F', 'Féminines'),
                  ],
                  actif: _genre,
                  onChoix: (v) => setState(() => _genre = v),
                ),
              ),

            Expanded(
              child: liste.isEmpty
                  ? ListView(
                      padding: const EdgeInsets.fromLTRB(14, 20, 14, 28),
                      children: [
                        CarteBlanche(
                          enfant: Vide(
                            message: miens.isEmpty
                                ? "Votre compte n'est habilité sur aucune "
                                      'catégorie : demandez à un '
                                      'administrateur du club de vous en '
                                      'attribuer une.'
                                : 'Aucun licencié pour cette sélection. '
                                      'Touchez + pour en créer un.',
                          ),
                        ),
                      ],
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(14, 20, 14, 28),
                      children: [
                        CarteBlanche(
                          enfant: Column(
                            children: [
                              for (var i = 0; i < liste.length; i++) ...[
                                if (i > 0) const Divider(height: 1),
                                _LigneJoueur(
                                  joueur: liste[i],
                                  etiquette: _etiquette(categories, liste[i]),
                                  onModifier: () async {
                                    await FormJoueurPage.ouvrir(
                                      context,
                                      joueur: liste[i],
                                    );
                                    ref.invalidate(tousLesJoueursProvider);
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// « 18M », « SF » — la même étiquette que dans les classements.
  String _etiquette(List<Categorie> categories, Joueur j) {
    for (final c in categories) {
      if (c.accueille(j.generation)) return '${c.code}${j.genre}';
    }
    return j.genre;
  }
}

/// Une bande blanche sous le bandeau, avec son filet de séparation.
class _Barre extends StatelessWidget {
  const _Barre({required this.enfant});

  final Widget enfant;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Couleurs.blanc,
        border: Border(bottom: BorderSide(color: Couleurs.ligne)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
      child: enfant,
    );
  }
}

/// Une rangée de pastilles qui défile horizontalement.
class _Rangee extends StatelessWidget {
  const _Rangee({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Couleurs.blanc,
        border: Border(bottom: BorderSide(color: Couleurs.ligne)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
        child: Row(
          children: [
            for (final p in children)
              Padding(
                padding: const EdgeInsets.only(right: 7),
                child: p,
              ),
          ],
        ),
      ),
    );
  }
}

class _LigneJoueur extends StatelessWidget {
  const _LigneJoueur({
    required this.joueur,
    required this.etiquette,
    required this.onModifier,
  });

  final Joueur joueur;
  final String etiquette;
  final VoidCallback onModifier;

  @override
  Widget build(BuildContext context) {
    final encre = joueur.actif ? Couleurs.nuit : Couleurs.gris2;

    return InkWell(
      onTap: onModifier,
      child: Opacity(
        opacity: joueur.actif ? 1 : 0.65,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            children: [
              Container(
                constraints: const BoxConstraints(minWidth: 30),
                height: 23,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  color: Couleurs.bleuClair,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  etiquette,
                  style: Typo.texte(
                    taille: 10.5,
                    graisse: 700,
                    couleur: Couleurs.bleu,
                    hauteurLigne: 1,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      joueur.nomComplet,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Typo.texte(
                        taille: 13,
                        graisse: 600,
                        couleur: encre,
                      ),
                    ),
                    if (!joueur.actif)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          'a quitté le club',
                          style: Typo.texte(
                            taille: 10.5,
                            couleur: Couleurs.gris2,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                size: 16,
                color: Couleurs.gris2,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
