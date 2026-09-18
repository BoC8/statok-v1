import 'categorie.dart';
import 'equipe.dart';
import 'joueur.dart';

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

  /// `'super_admin'`, `'admin'` ou `'coach'`.
  final String role;

  /// Vide pour un admin : il écrit partout.
  final List<Habilitation> habilitations;

  /// Le super administrateur : celui qui tient la structure du club.
  ///
  /// Catégories, équipes, paramètres, montée de génération — tout ce qui
  /// se répercute sur l'application entière. Le rôle est décidé en base
  /// et les politiques RLS l'appliquent ; ce que fait l'interface avec
  /// cette propriété n'est que du confort. Masquer un écran n'a jamais
  /// refusé un droit : un compte du staff peut appeler l'API Supabase
  /// sans passer par l'application.
  bool get estSuperAdmin => role == 'super_admin';

  /// Le super administrateur a tout ce qu'a un administrateur.
  /// `est_admin()` répond la même chose en base.
  bool get estAdmin => role == 'admin' || role == 'super_admin';

  /// Ce que l'interface autorise. La base tranche de toute façon : ces
  /// contrôles évitent de proposer un bouton qui finirait en erreur,
  /// ils ne remplacent pas les politiques RLS.
  bool peutEcrireEquipe(Equipe e) =>
      estAdmin || habilitations.any((h) => h.couvre(e));

  /// Ce coach peut-il modifier la fiche de ce licencié ?
  ///
  /// Un joueur n'a pas d'équipe : on passe par sa génération pour
  /// retrouver sa catégorie, exactement comme le fait la fonction
  /// `peut_ecrire_joueur` en base. Les deux doivent dire la même chose —
  /// si elles divergent, c'est la base qui a raison, et l'interface qui
  /// aura promis ce qu'elle ne pouvait pas tenir.
  bool peutEcrireJoueur(Joueur joueur, List<Categorie> categories) {
    if (estAdmin) return true;
    for (final h in habilitations) {
      if (h.genre != 'T' && h.genre != joueur.genre) continue;
      for (final c in categories) {
        if (c.id == h.categorieId && c.accueille(joueur.generation)) {
          return true;
        }
      }
    }
    return false;
  }

  /// Les générations que ce compte peut créer.
  ///
  /// Dédoublonnées : un coach habilité deux fois sur la même catégorie —
  /// une fois chez les garçons, une fois chez les filles — verrait
  /// sinon « U15 » proposé deux fois de suite.
  List<String> generationsAutorisees(List<Categorie> categories) {
    final permises = <String>{};
    for (final c in categories) {
      if (estAdmin || habilitations.any((h) => h.categorieId == c.id)) {
        permises.addAll(c.generations);
      }
    }
    return permises.toList();
  }

  /// Les genres que ce compte peut attribuer à un nouveau licencié.
  List<String> genresAutorises() {
    if (estAdmin) return const ['M', 'F'];
    final permis = <String>{};
    for (final h in habilitations) {
      if (h.genre == 'T') {
        permis.addAll(const ['M', 'F']);
      } else {
        permis.add(h.genre);
      }
    }
    return permis.toList()..sort();
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
