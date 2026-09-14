/// Ce qu'un écran affiche : soit **une équipe**, soit **toute une
/// catégorie** déclinée par genre.
///
/// POURQUOI UN SEUL OBJET POUR LES DEUX
///   « Les U18 A » et « Les U16 – U18 féminines » demandent exactement
///   les mêmes chiffres : un bilan, des matchs, un classement. Seule
///   change la liste d'équipes concernées. Un périmètre unique évite
///   d'écrire deux fois le même écran — et deux fois les mêmes bugs.
///
/// Cette classe sert de clé à des providers `family` : elle doit donc
/// avoir une égalité de valeur, sans quoi Riverpod créerait un cache
/// neuf à chaque reconstruction.
class Perimetre {
  const Perimetre.equipe(String id)
    : equipeId = id,
      categorieId = null,
      genre = null;

  const Perimetre.categorie({required String id, required this.genre})
    : categorieId = id,
      equipeId = null;

  /// Renseigné quand le périmètre est une seule équipe.
  final String? equipeId;

  /// Renseigné quand le périmètre est une catégorie entière.
  final String? categorieId;

  /// `'M'` ou `'F'`. Toujours présent avec une catégorie : on n'affiche
  /// jamais masculins et féminines mélangés.
  final String? genre;

  bool get estEquipe => equipeId != null;

  @override
  bool operator ==(Object other) =>
      other is Perimetre &&
      other.equipeId == equipeId &&
      other.categorieId == categorieId &&
      other.genre == genre;

  @override
  int get hashCode => Object.hash(equipeId, categorieId, genre);

  @override
  String toString() => estEquipe
      ? 'Perimetre.equipe($equipeId)'
      : 'Perimetre.categorie($categorieId, $genre)';
}
