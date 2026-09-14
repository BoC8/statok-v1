import 'generations.dart';

/// Un licencié du club.
///
/// PAS D'ÉQUIPE. Un joueur de génération 17 peut jouer en U18 A un
/// week-end et en U17 le suivant. Les équipes avec lesquelles il a
/// réellement joué se lisent sur ses buts, via la rencontre — jamais
/// sur sa fiche.
class Joueur {
  const Joueur({
    required this.id,
    required this.prenom,
    required this.nom,
    required this.generation,
    required this.genre,
    required this.actif,
  });

  final String id;
  final String prenom;
  final String nom;

  /// `'13'` à `'18'`, ou `'senior'`. Incrémentée chaque été par
  /// l'opération de montée.
  final String generation;

  final String genre;
  final bool actif;

  String get nomComplet => '$prenom $nom';

  /// « T. Cauchy » — pour les lignes serrées.
  String get nomCourt => prenom.isEmpty ? nom : '${prenom[0]}. $nom';

  String get initiales {
    final p = prenom.isEmpty ? '' : prenom[0];
    final n = nom.isEmpty ? '' : nom[0];
    return '$p$n'.toUpperCase();
  }

  /// « U17 » ou « Séniors ».
  String get libelleAge => libelleGeneration(generation);

  factory Joueur.depuisJson(Map<String, dynamic> j) => Joueur(
    id: j['id'] as String,
    prenom: j['prenom'] as String? ?? '',
    nom: j['nom'] as String? ?? '',
    generation: j['generation'] as String? ?? 'senior',
    genre: j['genre'] as String? ?? 'M',
    actif: j['actif'] as bool? ?? true,
  );
}
