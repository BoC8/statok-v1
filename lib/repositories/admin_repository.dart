import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/profil.dart';
import '../models/rencontre.dart';

/// Les écritures de l'espace coachs, et les lectures qui n'intéressent
/// que lui.
///
/// TOUTES LES ÉCRITURES SONT ARBITRÉES PAR LA BASE
///   Les politiques RLS décident, pas l'application. Si une requête est
///   refusée, Supabase lève une exception qu'on laisse remonter : mieux
///   vaut un message d'erreur franc qu'un enregistrement silencieusement
///   perdu.
class AdminRepository {
  AdminRepository({SupabaseClient? client})
    : _db = client ?? Supabase.instance.client;

  final SupabaseClient _db;

  // -------------------------------------------------------------------
  //  Le compte connecté
  // -------------------------------------------------------------------

  /// Le profil de l'utilisateur connecté, ou `null` s'il n'y en a pas.
  ///
  /// Renvoie aussi `null` si le compte existe dans `auth.users` mais n'a
  /// pas de fiche dans `profils` : c'est un compte créé sans être
  /// rattaché au staff, il ne doit rien pouvoir faire.
  Future<Profil?> profil() async {
    final utilisateur = _db.auth.currentUser;
    if (utilisateur == null) return null;

    final fiche = await _db
        .from('profils')
        .select('id, nom, role')
        .eq('id', utilisateur.id)
        .maybeSingle();
    if (fiche == null) return null;

    final habilitations = await _db
        .from('coach_categories')
        .select('categorie_id, genre')
        .eq('utilisateur_id', utilisateur.id);

    return Profil.depuisJson(fiche, [
      for (final h in habilitations) Habilitation.depuisJson(h),
    ]);
  }

  Future<void> connexion({
    required String email,
    required String motDePasse,
  }) async {
    await _db.auth.signInWithPassword(email: email, password: motDePasse);
  }

  Future<void> deconnexion() => _db.auth.signOut();

  // -------------------------------------------------------------------
  //  Les listes du formulaire
  // -------------------------------------------------------------------

  /// Les compétitions auxquelles une équipe est engagée cette saison.
  ///
  /// C'est la garantie applicative dont parle `ARCHITECTURE` : la base
  /// n'impose pas qu'une rencontre corresponde à un engagement, c'est
  /// cette liste qui l'assure.
  Future<List<OptionCompetition>> engagements({
    required String equipeId,
    required String saisonId,
  }) async {
    final lignes = await _db
        .from('engagements')
        .select('phase, competitions(id, nom, type)')
        .eq('equipe_id', equipeId)
        .eq('saison_id', saisonId);

    final options = lignes
        .map((l) => OptionCompetition.depuisJson(l))
        .toList();

    // Championnats d'abord, puis coupes, puis amicaux ; par phase.
    const rang = {'championnat': 0, 'coupe': 1, 'amical': 2};
    options.sort((a, b) {
      final parType = (rang[a.type] ?? 9).compareTo(rang[b.type] ?? 9);
      if (parType != 0) return parType;
      final parPhase = a.phase.compareTo(b.phase);
      return parPhase != 0 ? parPhase : a.nom.compareTo(b.nom);
    });
    return options;
  }

  Future<List<Adversaire>> adversaires() async {
    final lignes = await _db
        .from('adversaires')
        .select('id, nom')
        .order('nom');
    return lignes.map((l) => Adversaire.depuisJson(l)).toList();
  }

  /// Crée un adversaire, ou renvoie celui qui porte déjà ce nom.
  ///
  /// La contrainte d'unicité sur le nom fait le travail : plutôt que de
  /// vérifier puis insérer — ce qui laisse une fenêtre entre les deux —
  /// on insère en demandant à Postgres de ne rien faire en cas de
  /// conflit, puis on relit.
  Future<Adversaire> creerAdversaire(String nom) async {
    final propre = nom.trim();
    await _db.from('adversaires').upsert(
      {'nom': propre},
      onConflict: 'nom',
      ignoreDuplicates: true,
    );
    final ligne = await _db
        .from('adversaires')
        .select('id, nom')
        .eq('nom', propre)
        .single();
    return Adversaire.depuisJson(ligne);
  }

  // -------------------------------------------------------------------
  //  Les rencontres
  // -------------------------------------------------------------------

  /// Crée ou met à jour une rencontre, avec son détail.
  ///
  /// Renvoie l'identifiant de la rencontre.
  ///
  /// LES BUTS ET LES TIRS SONT REMPLACÉS EN BLOC
  ///   Corriger une feuille de match ligne à ligne demanderait de suivre
  ///   ce que le coach a ajouté, modifié ou retiré. On efface et on
  ///   réécrit : c'est plus court, et surtout on ne peut pas se
  ///   retrouver avec un but fantôme qu'un bug aurait oublié de
  ///   supprimer.
  Future<String> enregistrerRencontre({
    String? id,
    required String saisonId,
    required String equipeId,
    required String competitionId,
    required String adversaireId,
    required int phase,
    required DateTime dateHeure,
    required bool domicile,
    required String statut,
    int? scorePour,
    int? scoreContre,
    int? tabPour,
    int? tabContre,
    required List<But> buts,
    required List<TirAuBut> tirsAuBut,
  }) async {
    final donnees = {
      if (id != null) 'id': id,
      'saison_id': saisonId,
      'equipe_id': equipeId,
      'competition_id': competitionId,
      'adversaire_id': adversaireId,
      'phase': phase,
      'date_heure': dateHeure.toUtc().toIso8601String(),
      'domicile': domicile,
      'statut': statut,
      'score_pour': scorePour,
      'score_contre': scoreContre,
      'tab_pour': tabPour,
      'tab_contre': tabContre,
    };

    final ligne = await _db
        .from('rencontres')
        .upsert(donnees)
        .select('id')
        .single();
    final rencontreId = ligne['id'] as String;

    await _db.from('buts').delete().eq('rencontre_id', rencontreId);
    if (buts.isNotEmpty) {
      await _db.from('buts').insert([
        for (final b in buts)
          {
            'rencontre_id': rencontreId,
            'joueur_id': b.joueurId,
            'passeur_id': b.passeurId,
            'csc': b.csc,
          },
      ]);
    }

    await _db.from('tirs_au_but').delete().eq('rencontre_id', rencontreId);
    if (tirsAuBut.isNotEmpty) {
      await _db.from('tirs_au_but').insert([
        for (final t in tirsAuBut)
          {
            'rencontre_id': rencontreId,
            'ordre': t.ordre,
            'joueur_id': t.joueurId,
            'marque': t.marque,
          },
      ]);
    }

    return rencontreId;
  }

  /// Supprime une rencontre. Ses buts et ses tirs au but partent avec
  /// elle : la clé étrangère est en cascade.
  Future<void> supprimerRencontre(String id) async {
    await _db.from('rencontres').delete().eq('id', id);
  }
}
