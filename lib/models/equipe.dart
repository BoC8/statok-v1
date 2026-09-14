import 'generations.dart';

/// Une équipe engagée du club.
///
/// Le croisement catégorie + genre forme les six groupes qui servent de
/// filtre dans toute l'application.
class Equipe {
  const Equipe({
    required this.id,
    required this.categorieId,
    required this.genre,
    required this.nom,
    required this.ordre,
    required this.generationMax,
    required this.actif,
  });

  final String id;
  final String categorieId;

  /// `'M'` ou `'F'`.
  final String genre;

  /// Déjà court — « U15 B », « Seniors A » — et affiché tel quel dans les
  /// lignes de match. Il n'y a pas de nom abrégé séparé.
  final String nom;

  /// La position dans son groupe. Indispensable : l'ordre voulu n'est pas
  /// alphabétique — U18 A passe avant U17.
  final int ordre;

  /// La tranche d'âge la plus élevée que l'équipe accueille.
  ///
  /// La catégorie ne suffit pas : « U16 – U18 » contient l'U18 A et
  /// l'U17, et un licencié de génération 18 n'a rien à faire chez les
  /// U17 — il est trop vieux d'un an.
  final String generationMax;

  /// Une équipe dissoute passe à `false` et garde tout son historique.
  final bool actif;

  bool get estFeminine => genre == 'F';

  /// Ce joueur peut-il évoluer dans cette équipe ?
  ///
  /// Le surclassement est permis — un jeune joue plus haut que son âge —
  /// mais jamais l'inverse.
  bool accepteGeneration(String generation) {
    final joueur = rangGeneration(generation);
    final plafond = rangGeneration(generationMax);
    if (joueur < 0 || plafond < 0) return true;
    return joueur <= plafond;
  }

  factory Equipe.depuisJson(Map<String, dynamic> j) => Equipe(
    id: j['id'] as String,
    categorieId: j['categorie_id'] as String,
    genre: j['genre'] as String,
    nom: j['nom'] as String,
    ordre: j['ordre'] as int? ?? 1,
    generationMax: j['generation_max'] as String? ?? 'senior',
    actif: j['actif'] as bool? ?? true,
  );
}
