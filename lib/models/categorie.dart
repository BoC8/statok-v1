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

  factory Categorie.depuisJson(Map<String, dynamic> j) => Categorie(
    id: j['id'] as String,
    libelle: j['libelle'] as String,
    ordre: j['ordre'] as int,
    generations: (j['generations'] as List<dynamic>? ?? const [])
        .map((e) => e.toString())
        .toList(),
  );
}
