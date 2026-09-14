/// Une saison du club, de juillet à juin.
///
/// `anneeDebut` porte toute la logique — tri, comparaison, calcul de la
/// catégorie d'âge d'un joueur. `libelle` n'est que de l'affichage.
class Saison {
  const Saison({
    required this.id,
    required this.anneeDebut,
    required this.libelle,
    required this.enCours,
    required this.monteeFaite,
  });

  final String id;
  final int anneeDebut;
  final String libelle;

  /// Une seule saison est en cours à la fois : la base l'impose par un
  /// index unique partiel.
  final bool enCours;

  /// La montée de catégorie est irréversible. Ce drapeau permet à
  /// l'espace coachs de refuser une seconde exécution.
  final bool monteeFaite;

  factory Saison.depuisJson(Map<String, dynamic> j) => Saison(
    id: j['id'] as String,
    anneeDebut: j['annee_debut'] as int,
    libelle: j['libelle'] as String,
    enCours: j['en_cours'] as bool? ?? false,
    monteeFaite: j['montee_faite'] as bool? ?? false,
  );
}
