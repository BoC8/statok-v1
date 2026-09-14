import 'equipe.dart';

/// Une habilitation : le droit d'écrire sur une catégorie, éventuellement
/// restreint à un genre.
class Habilitation {
  const Habilitation({required this.categorieId, required this.genre});

  final String categorieId;

  /// `'M'`, `'F'` ou `'T'` pour les deux.
  final String genre;

  bool couvre(Equipe e) =>
      e.categorieId == categorieId && (genre == 'T' || genre == e.genre);

  factory Habilitation.depuisJson(Map<String, dynamic> j) => Habilitation(
    categorieId: j['categorie_id'] as String,
    genre: j['genre'] as String? ?? 'T',
  );
}

/// Le compte d'un membre du staff.
///
/// `auth.users` appartient à Supabase et n'accepte pas de colonnes
/// supplémentaires : la table `profils` la prolonge, avec le même
/// identifiant.
class Profil {
  const Profil({
    required this.id,
    required this.nom,
    required this.role,
    required this.habilitations,
  });

  final String id;
  final String nom;

  /// `'admin'` ou `'coach'`.
  final String role;

  /// Vide pour un admin : il écrit partout.
  final List<Habilitation> habilitations;

  bool get estAdmin => role == 'admin';

  /// Ce que l'interface autorise. La base tranche de toute façon : ces
  /// contrôles évitent de proposer un bouton qui finirait en erreur,
  /// ils ne remplacent pas les politiques RLS.
  bool peutEcrireEquipe(Equipe e) =>
      estAdmin || habilitations.any((h) => h.couvre(e));

  bool peutEcrireJoueur({required String generation, required String genre}) {
    if (estAdmin) return true;
    // On ne connaît pas ici la correspondance génération → catégorie :
    // elle vit dans la base. L'interface reste donc permissive et laisse
    // la RLS refuser ; c'est le seul endroit où l'on procède ainsi.
    return habilitations.isNotEmpty;
  }

  factory Profil.depuisJson(
    Map<String, dynamic> j,
    List<Habilitation> habilitations,
  ) => Profil(
    id: j['id'] as String,
    nom: j['nom'] as String? ?? '',
    role: j['role'] as String? ?? 'coach',
    habilitations: habilitations,
  );
}

/// Une compétition à laquelle une équipe est engagée cette saison.
///
/// C'est ce que le formulaire de saisie propose : on ne peut pas
/// enregistrer un match dans une compétition où l'équipe n'est pas
/// inscrite. La base ne l'impose pas — c'est ici que ça se joue.
class OptionCompetition {
  const OptionCompetition({
    required this.competitionId,
    required this.nom,
    required this.type,
    required this.phase,
  });

  final String competitionId;
  final String nom;
  final String type;
  final int phase;

  String get libelle => phase > 0 ? '$nom · phase $phase' : nom;

  /// Identifiant d'affichage : deux engagements ne diffèrent parfois que
  /// par leur phase.
  String get cle => '$competitionId~$phase';

  factory OptionCompetition.depuisJson(Map<String, dynamic> j) {
    final c = j['competitions'] as Map<String, dynamic>?;
    return OptionCompetition(
      competitionId: c?['id'] as String? ?? '',
      nom: c?['nom'] as String? ?? '',
      type: c?['type'] as String? ?? 'championnat',
      phase: j['phase'] as int? ?? 0,
    );
  }
}

/// Une équipe adverse déjà rencontrée.
class Adversaire {
  const Adversaire({required this.id, required this.nom});

  final String id;
  final String nom;

  factory Adversaire.depuisJson(Map<String, dynamic> j) =>
      Adversaire(id: j['id'] as String, nom: j['nom'] as String);
}
