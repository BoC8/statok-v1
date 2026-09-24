import 'categorie.dart';
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

/// Range des équipes dans l'ordre dont on parle au club : les plus âgés
/// d'abord, masculins avant féminines, puis l'ordre interne au groupe.
///
///     Seniors A · Seniors B · Seniors F · U18 A · U18 F · U15 · U15 F
///
/// POURQUOI L'ÂGE ET NON `Categorie.ordre`
///   `ordre` est une position d'affichage que le super administrateur
///   peut réarranger depuis l'écran de structure. S'en servir pour
///   raisonner sur l'âge marcherait aujourd'hui et se tromperait le jour
///   où quelqu'un déplace une ligne. L'âge se lit dans les générations,
///   qui sont la donnée — c'est déjà ce que fait `Categorie.rangAge`,
///   et ce que suivent les puces de filtre des écrans publics.
///
/// POURQUOI UNE FONCTION ET NON UN TRI DANS LA REQUÊTE
///   La base ne connaît pas cet ordre : il se déduit des générations de
///   la catégorie, qui vivent dans un tableau. Le calculer ici le rend
///   identique partout et vérifiable par un test.
///
/// La liste reçue n'est pas modifiée.
List<Equipe> rangerEquipes(List<Equipe> equipes, List<Categorie> categories) {
  final parId = {for (final c in categories) c.id: c};

  int age(Equipe e) => parId[e.categorieId]?.rangAge ?? -1;
  int rangCategorie(Equipe e) => parId[e.categorieId]?.ordre ?? 0;
  String libelleCategorie(Equipe e) => parId[e.categorieId]?.libelle ?? '';

  return [...equipes]..sort((a, b) {
    // Du plus âgé au plus jeune : Seniors, puis U18, puis U15.
    final parAge = age(b).compareTo(age(a));
    if (parAge != 0) return parAge;

    // Deux catégories peuvent plafonner à la même génération — un club
    // qui séparerait « U18 » et « U17 – U18 », par exemple. On retombe
    // alors sur la position d'affichage, puis sur le libellé, pour que
    // l'ordre reste le même d'un affichage à l'autre.
    final parOrdre = rangCategorie(a).compareTo(rangCategorie(b));
    if (parOrdre != 0) return parOrdre;
    final parLibelle = libelleCategorie(a).compareTo(libelleCategorie(b));
    if (parLibelle != 0) return parLibelle;

    // Masculins avant féminines, comme partout ailleurs.
    if (a.genre != b.genre) return a.genre == 'M' ? -1 : 1;

    // Enfin l'ordre voulu au sein du groupe : U18 A avant U17.
    final parRang = a.ordre.compareTo(b.ordre);
    if (parRang != 0) return parRang;
    return a.nom.toLowerCase().compareTo(b.nom.toLowerCase());
  });
}
