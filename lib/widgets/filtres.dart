import 'package:flutter/material.dart';

import '../providers/donnees_saison.dart';
import '../theme/app_theme.dart';
import 'communs.dart';

/// Les filtres communs à l'accueil, au calendrier et aux classements.
///
/// Ils vivent ici parce que les trois écrans les affichent à l'identique.
/// C'est la même leçon que pour les couleurs : une règle écrite une fois
/// ne peut pas diverger entre deux pages.

/// La rangée « Tout le club » suivie des groupes qui ont quelque chose
/// à montrer.
///
/// ON NE PROPOSE QUE CE QUI EXISTE
///   Afficher les six groupes en toutes circonstances conduit à des
///   écrans vides : sur la saison 2025-2026, choisir « Seniors M »
///   n'aurait rien ramené, sans qu'on comprenne pourquoi. Un groupe
///   n'apparaît donc que si l'une de ses équipes a au moins une
///   rencontre — jouée ou programmée — dans la saison affichée.
class ChipsGroupes extends StatelessWidget {
  const ChipsGroupes({
    super.key,
    required this.donnees,
    required this.filtre,
    required this.onChange,
    this.avant,
  });

  final DonneesSaison donnees;
  final FiltreClub filtre;
  final ValueChanged<FiltreClub> onChange;

  /// Un bouton posé avant les puces, hors défilement — celui des
  /// compétitions.
  final Widget? avant;

  String _cle(String categorieId, String genre) => '$categorieId~$genre';

  @override
  Widget build(BuildContext context) {
    // Les équipes qui ont au moins une rencontre cette saison.
    final actives = donnees.rencontres.map((r) => r.equipeId).toSet();

    // DU PLUS VIEUX AU PLUS JEUNE
    //   Seniors d'abord, U14–U15 en dernier — l'inverse de l'ordre
    //   d'affichage des autres écrans. C'est celui qu'on suit à l'oral
    //   au club : on parle des seniors, puis on descend. Le tri porte
    //   sur l'âge réel de la catégorie, pas sur sa position
    //   d'affichage : voir `Categorie.rangAge`.
    final categories = [...donnees.categories]
      ..sort((a, b) => b.rangAge.compareTo(a.rangAge));

    final options = <(String, String)>[
      ('tout', 'Tout le club'),
      for (final c in categories)
        // Masculins avant féminines, à l'intérieur de chaque catégorie.
        for (final genre in const ['M', 'F'])
          if (donnees
              .equipesDuGroupe(c.id, genre)
              .any((e) => actives.contains(e.id)))
            (
              _cle(c.id, genre),
              '${c.libelle} ${genre == 'F' ? 'F' : 'M'}',
            ),
    ];

    final actif = filtre.categorieId == null
        ? 'tout'
        : _cle(filtre.categorieId!, filtre.genre ?? 'M');

    return Container(
      decoration: const BoxDecoration(
        color: Couleurs.blanc,
        border: Border(bottom: BorderSide(color: Couleurs.ligne)),
      ),
      child: Row(
        children: [
          if (avant != null)
            Padding(
              padding: const EdgeInsets.only(left: 14),
              child: avant!,
            ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.fromLTRB(avant == null ? 14 : 9, 11, 14, 11),
              child: Row(
                children: [
                  for (final (valeur, libelle) in options)
                    Padding(
                      padding: const EdgeInsets.only(right: 7),
                      child: PuceFiltre(
                        libelle: libelle,
                        choisi: valeur == actif,
                        // Changer de groupe remet l'équipe à zéro :
                        // garder « U18 A » en passant chez les Seniors
                        // n'aurait aucun sens.
                        onTap: () => onChange(
                          valeur == 'tout'
                              ? filtre.avecGroupe(null, null)
                              : filtre.avecGroupe(
                                  valeur.split('~').first,
                                  valeur.split('~').last,
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
    );
  }
}

/// La rangée des équipes du groupe choisi. Ne s'affiche que s'il y en a
/// plusieurs : proposer « Toutes les équipes » puis une seule ligne
/// serait un choix sans choix.
class ChipsEquipes extends StatelessWidget {
  const ChipsEquipes({
    super.key,
    required this.donnees,
    required this.filtre,
    required this.onChange,
  });

  final DonneesSaison donnees;
  final FiltreClub filtre;
  final ValueChanged<FiltreClub> onChange;

  @override
  Widget build(BuildContext context) {
    if (filtre.categorieId == null) return const SizedBox.shrink();
    final equipes = donnees.equipesDuGroupe(
      filtre.categorieId!,
      filtre.genre ?? 'M',
    );
    if (equipes.length < 2) return const SizedBox.shrink();

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
            Padding(
              padding: const EdgeInsets.only(right: 7),
              child: PuceFiltre(
                libelle: 'Toutes les équipes',
                choisi: filtre.equipeId == null,
                onTap: () => onChange(filtre.avecEquipe(null)),
              ),
            ),
            for (final e in equipes)
              Padding(
                padding: const EdgeInsets.only(right: 7),
                child: PuceFiltre(
                  libelle: e.nom,
                  choisi: filtre.equipeId == e.id,
                  onTap: () => onChange(filtre.avecEquipe(e.id)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Le bouton entonnoir, avec sa pastille de compte.
class BoutonCompetitions extends StatelessWidget {
  const BoutonCompetitions({
    super.key,
    required this.nombre,
    required this.onTap,
  });

  final int nombre;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 31,
            height: 31,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: nombre > 0 ? Couleurs.nuit : Couleurs.blanc,
              border: Border.all(
                color: nombre > 0 ? Couleurs.nuit : Couleurs.ligne,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.filter_list,
              size: 16,
              color: nombre > 0 ? Colors.white : Couleurs.nuit,
            ),
          ),
          if (nombre > 0)
            Positioned(
              top: -5,
              right: -5,
              child: Container(
                constraints: const BoxConstraints(minWidth: 16),
                height: 16,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: Couleurs.or,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Couleurs.blanc, width: 2),
                ),
                child: Text(
                  '$nombre',
                  style: Typo.texte(
                    taille: 9.5,
                    graisse: 800,
                    couleur: const Color(0xFF3A2600),
                    hauteurLigne: 1,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

const _libelleType = {
  'championnat': 'Championnat',
  'coupe': 'Coupe',
  'amical': 'Amical',
};

/// Ouvre le panneau de choix des compétitions et rend le filtre modifié.
///
/// Ne propose que ce qui existe réellement dans la sélection courante :
/// un filtre qui ne ramènerait rien est un piège, pas une option.
Future<FiltreClub?> choisirCompetitions(
  BuildContext context, {
  required DonneesSaison donnees,
  required FiltreClub filtre,
}) {
  return showModalBottomSheet<FiltreClub>(
    context: context,
    backgroundColor: Couleurs.blanc,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _PanneauCompetitions(donnees: donnees, filtreInitial: filtre),
  );
}

class _PanneauCompetitions extends StatefulWidget {
  const _PanneauCompetitions({
    required this.donnees,
    required this.filtreInitial,
  });

  final DonneesSaison donnees;
  final FiltreClub filtreInitial;

  @override
  State<_PanneauCompetitions> createState() => _PanneauCompetitionsState();
}

class _PanneauCompetitionsState extends State<_PanneauCompetitions> {
  late Set<String> _types = {...widget.filtreInitial.types};
  late Set<String> _competitions = {...widget.filtreInitial.competitions};

  FiltreClub get _filtre => widget.filtreInitial.avecCompetitions(
    types: _types,
    competitions: _competitions,
  );

  void _basculer(Set<String> ensemble, String valeur) {
    setState(() {
      if (!ensemble.remove(valeur)) ensemble.add(valeur);
    });
  }

  @override
  Widget build(BuildContext context) {
    final types = widget.donnees.typesDisponibles(_filtre);
    final competitions = widget.donnees.competitionsDisponibles(_filtre);

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.74,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(
                color: Couleurs.ligne,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 11),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Compétitions',
                      style: Typo.texte(taille: 14, graisse: 700),
                    ),
                  ),
                  if (_types.isNotEmpty || _competitions.isNotEmpty)
                    GestureDetector(
                      onTap: () => setState(() {
                        _types = {};
                        _competitions = {};
                      }),
                      child: Text(
                        'Tout effacer',
                        style: Typo.texte(
                          taille: 12.5,
                          graisse: 600,
                          couleur: Couleurs.bleu,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 13, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Bloc(
                      titre: 'Type',
                      options: [
                        for (final t in types) (t, _libelleType[t] ?? t),
                      ],
                      choisis: _types,
                      onBascule: (v) => _basculer(_types, v),
                    ),
                    _Bloc(
                      titre: 'Compétition',
                      options: [for (final c in competitions) (c, c)],
                      choisis: _competitions,
                      onBascule: (v) => _basculer(_competitions, v),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Sans sélection, toutes les compétitions de la '
                      'catégorie choisie sont affichées.',
                      style: Typo.texte(
                        taille: 11,
                        couleur: Couleurs.gris,
                        hauteurLigne: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 11, 16, 11),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Couleurs.bleu,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  onPressed: () => Navigator.of(context).pop(_filtre),
                  child: Text(
                    'Afficher',
                    style: Typo.texte(
                      taille: 14,
                      graisse: 700,
                      couleur: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bloc extends StatelessWidget {
  const _Bloc({
    required this.titre,
    required this.options,
    required this.choisis,
    required this.onBascule,
  });

  final String titre;
  final List<(String, String)> options;
  final Set<String> choisis;
  final ValueChanged<String> onBascule;

  @override
  Widget build(BuildContext context) {
    if (options.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titre,
            style: Typo.texte(
              taille: 11.5,
              graisse: 600,
              couleur: Couleurs.gris,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final (valeur, libelle) in options)
                PuceFiltre(
                  libelle: libelle,
                  choisi: choisis.contains(valeur),
                  onTap: () => onBascule(valeur),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
