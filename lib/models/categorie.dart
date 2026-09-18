import 'generations.dart';

/// Une catégorie du club : U14 – U15, U16 – U18, Seniors.
///
/// C'est aussi le niveau auquel les droits des coachs sont attribués.
class Categorie {
  const Categorie({
    required this.id,
    required this.libelle,
    required this.ordre,
    required this.generations,
  });

  final String id;
  final String libelle;

  /// Fixe la position d'affichage partout : 1 = les plus jeunes.
  final int ordre;

  /// Les tranches d'âge accueillies : `{13, 14, 15}`, `{senior}`…
  ///
  /// C'est par là qu'on retrouve la catégorie d'un joueur, puisqu'un
  /// licencié n'appartient à aucune équipe fixe.
  final List<String> generations;

  /// La tranche d'âge la plus élevée que la catégorie accueille, ou
  /// `null` si elle n'en accueille aucune.
  String? get generationLaPlusAgee {
    String? plusAgee;
    for (final g in generations) {
      if (plusAgee == null || rangGeneration(g) > rangGeneration(plusAgee)) {
        plusAgee = g;
      }
    }
    return plusAgee;
  }

  /// Le rang de cette tranche, pour trier les catégories par âge.
  ///
  /// POURQUOI PAS `ordre`
  ///   `ordre` est une position d'affichage, que le super administrateur
  ///   peut changer depuis l'écran de structure. S'en servir pour
  ///   raisonner sur l'âge marcherait aujourd'hui et se tromperait le
  ///   jour où quelqu'un réarrange la liste. L'âge se lit dans les
  ///   générations, qui sont la donnée.
  int get rangAge {
    final g = generationLaPlusAgee;
    return g == null ? -1 : rangGeneration(g);
  }

  /// L'abréviation affichée dans les étiquettes : « 15 », « 18 », « S ».
  ///
  /// Elle se déduit de la tranche d'âge la plus élevée que la catégorie
  /// accueille — c'est ainsi qu'on la nomme oralement au club. Rien à
  /// stocker, rien à tenir à jour.
  String get code {
    final plusAgee = generationLaPlusAgee;
    if (plusAgee == null) return '?';
    return plusAgee == 'senior' ? 'S' : plusAgee;
  }

  bool accueille(String generation) => generations.contains(generation);

  factory Categorie.depuisJson(Map<String, dynamic> j) => Categorie(
    id: j['id'] as String,
    libelle: j['libelle'] as String,
    ordre: j['ordre'] as int,
    generations: (j['generations'] as List<dynamic>? ?? const [])
        .map((e) => e.toString())
        .toList(),
  );
}
