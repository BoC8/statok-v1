import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/competition.dart';
import '../models/equipe.dart';
import '../models/profil.dart';
import '../models/joueur.dart';
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
    String? forfait,
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
      'forfait': forfait,
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

  /// Les rencontres d'une saison donnée, pour l'espace coachs.
  ///
  /// Distinct de ce que `DonneesSaison` garde en mémoire : celui-ci suit
  /// le sélecteur de saison des écrans publics, alors que le staff
  /// travaille sur *sa* saison — la saison en cours pour un coach, la
  /// saison consultée pour un administrateur.
  Future<List<Rencontre>> rencontresDeLaSaison(String saisonId) async {
    final lignes = await _db
        .from('rencontres')
        .select(
          'id, saison_id, equipe_id, phase, date_heure, domicile, statut, '
          'forfait, score_pour, score_contre, tab_pour, tab_contre, '
          'adversaires(nom), competitions(nom, type)',
        )
        .eq('saison_id', saisonId)
        .order('date_heure', ascending: false);
    return lignes.map((l) => Rencontre.depuisJson(l)).toList();
  }

  /// La feuille de match d'une rencontre précise.
  ///
  /// POURQUOI NE PAS LA PRENDRE DANS `DonneesSaison`
  ///   Ce qui est en mémoire, c'est la saison *consultée*. Rouvrir un
  ///   match d'une autre saison n'y trouverait aucun but — et comme le
  ///   formulaire réécrit la feuille en bloc, enregistrer effacerait
  ///   tout. On relit donc la fiche elle-même : deux requêtes, à
  ///   l'ouverture seulement.
  Future<(List<But>, List<TirAuBut>)> detailRencontre(String id) async {
    final buts = await _db
        .from('buts')
        .select('rencontre_id, joueur_id, passeur_id, csc')
        .eq('rencontre_id', id);
    final tirs = await _db
        .from('tirs_au_but')
        .select('rencontre_id, ordre, joueur_id, marque')
        .eq('rencontre_id', id)
        .order('ordre');

    return (
      buts.map((l) => But.depuisJson(l)).toList(),
      tirs.map((l) => TirAuBut.depuisJson(l)).toList(),
    );
  }

  /// Supprime une rencontre. Ses buts et ses tirs au but partent avec
  /// elle : la clé étrangère est en cascade.
  Future<void> supprimerRencontre(String id) async {
    await _db.from('rencontres').delete().eq('id', id);
  }

  // -------------------------------------------------------------------
  //  Les licenciés
  // -------------------------------------------------------------------

  /// Tous les licenciés, y compris ceux qui ont quitté le club.
  ///
  /// Les écrans publics ne montrent que les actifs ; l'espace coachs a
  /// besoin des autres pour pouvoir en réactiver un qui revient.
  Future<List<Joueur>> tousLesJoueurs() async {
    final lignes = await _db
        .from('joueurs')
        .select('id, prenom, nom, generation, genre, actif')
        .order('nom');
    return lignes.map((l) => Joueur.depuisJson(l)).toList();
  }

  /// Crée ou met à jour un licencié.
  ///
  /// CHANGER UN NOM NE COÛTE RIEN
  ///   Les buts référencent l'identifiant, jamais le nom. Corriger une
  ///   faute de frappe, ou le nom d'usage de quelqu'un, laisse toutes
  ///   ses statistiques intactes.
  Future<void> enregistrerJoueur({
    String? id,
    required String prenom,
    required String nom,
    required String generation,
    required String genre,
    required bool actif,
  }) async {
    await _db.from('joueurs').upsert({
      if (id != null) 'id': id,
      'prenom': prenom.trim(),
      'nom': nom.trim(),
      'generation': generation,
      'genre': genre,
      'actif': actif,
    });
  }

  /// Retire un licencié de l'effectif — sans effacer son passé.
  ///
  /// ON NE SUPPRIME PAS UN JOUEUR QUI A JOUÉ
  ///   `buts.joueur_id` est en `on delete restrict` : la base refuse
  ///   d'effacer quelqu'un dont un but dépend, et c'est voulu. Un
  ///   départ se marque par `actif = false` : le joueur disparaît des
  ///   listes de saisie, mais ses buts restent au crédit des équipes
  ///   pour lesquelles il les a marqués.
  Future<void> changerActivite(String id, bool actif) async {
    await _db.from('joueurs').update({'actif': actif}).eq('id', id);
  }

  /// Efface définitivement un licencié.
  ///
  /// N'aboutit que s'il n'a jamais marqué ni tiré : sinon la base
  /// refuse, et c'est la désactivation qu'il faut employer. Sert aux
  /// fiches créées par erreur.
  Future<void> supprimerJoueur(String id) async {
    await _db.from('joueurs').delete().eq('id', id);
  }

  // -------------------------------------------------------------------
  //  Les paramètres de l'application
  // -------------------------------------------------------------------

  /// Les textes et réglages modifiables sans reprendre le code.
  ///
  /// Table clé / valeur volontairement bête : ajouter un paramètre ne
  /// demande ni migration ni nouvelle colonne.
  Future<Map<String, String>> parametres() async {
    final lignes = await _db.from('parametres').select('cle, valeur');
    return {
      for (final l in lignes) l['cle'] as String: l['valeur'] as String? ?? '',
    };
  }

  Future<void> enregistrerParametre(String cle, String valeur) async {
    await _db.from('parametres').upsert({
      'cle': cle,
      'valeur': valeur,
      'modifie_le': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'cle');
  }

  // -------------------------------------------------------------------
  //  La montée de catégorie
  // -------------------------------------------------------------------

  /// Fait vieillir tout le club d'une génération.
  ///
  /// TOUT SE PASSE EN BASE, ET C'EST ESSENTIEL
  ///   Le travail est fait par la fonction `monter_les_generations()`,
  ///   pas ici. Une boucle côté application enverrait soixante requêtes
  ///   dont certaines pourraient échouer au milieu, laissant la moitié
  ///   du club vieillie et l'autre non — un état dont on ne se remet
  ///   pas, puisque rien ne dit qui était en U16 avant.
  ///
  ///   La fonction vérifie elle-même le rôle et le drapeau
  ///   `saisons.montee_faite`. Ses refus arrivent ici sous forme
  ///   d'exceptions, qu'on laisse remonter telles quelles.
  ///
  /// Renvoie `{saison, promus, detail}`.
  Future<Map<String, dynamic>> monterLesGenerations() async {
    final reponse = await _db.rpc('monter_les_generations');
    return Map<String, dynamic>.from(reponse as Map);
  }

  // -------------------------------------------------------------------
  //  La structure : catégories, équipes, compétitions
  // -------------------------------------------------------------------

  /// Toutes les équipes, y compris celles qui ne sont plus alignées.
  ///
  /// `ClubRepository.equipes()` ne rend que les actives, parce que c'est
  /// ce que les écrans publics doivent montrer. L'écran de structure a
  /// besoin des autres : c'est là qu'on réactive une équipe.
  Future<List<Equipe>> toutesLesEquipes() async {
    final lignes = await _db
        .from('equipes')
        .select('id, categorie_id, genre, nom, ordre, generation_max, actif')
        .order('ordre');
    return lignes.map((l) => Equipe.depuisJson(l)).toList();
  }

  /// Crée ou met à jour une catégorie.
  ///
  /// `generations` est la liste des tranches d'âge accueillies. Les
  /// catégories doivent rester **disjointes** : c'est par cette liste
  /// qu'on retrouve la catégorie d'un licencié, qui n'a pas d'équipe
  /// fixe. Deux catégories revendiquant la génération 15 rendraient ce
  /// rattachement arbitraire — et donc les droits des coachs avec.
  Future<void> enregistrerCategorie({
    String? id,
    required String libelle,
    required int ordre,
    required List<String> generations,
  }) async {
    await _db.from('categories').upsert({
      if (id != null) 'id': id,
      'libelle': libelle.trim(),
      'ordre': ordre,
      'generations': generations,
    });
  }

  Future<void> enregistrerEquipe({
    String? id,
    required String categorieId,
    required String genre,
    required String nom,
    required int ordre,
    required String generationMax,
    required bool actif,
  }) async {
    await _db.from('equipes').upsert({
      if (id != null) 'id': id,
      'categorie_id': categorieId,
      'genre': genre,
      'nom': nom.trim(),
      'ordre': ordre,
      'generation_max': generationMax,
      'actif': actif,
    });
  }

  Future<List<Competition>> competitions() async {
    final lignes = await _db
        .from('competitions')
        .select('id, nom, type')
        .order('nom');
    return lignes.map((l) => Competition.depuisJson(l)).toList();
  }

  /// Crée une compétition, ou renvoie celle qui porte déjà ce nom.
  ///
  /// Même parade que pour les adversaires : on laisse la contrainte
  /// d'unicité trancher plutôt que de vérifier puis insérer.
  Future<Competition> creerCompetition({
    required String nom,
    required String type,
  }) async {
    final propre = nom.trim();
    await _db.from('competitions').upsert({
      'nom': propre,
      'type': type,
    }, onConflict: 'nom', ignoreDuplicates: true);
    final ligne = await _db
        .from('competitions')
        .select('id, nom, type')
        .eq('nom', propre)
        .single();
    return Competition.depuisJson(ligne);
  }

  // -------------------------------------------------------------------
  //  Les engagements
  // -------------------------------------------------------------------

  /// Les inscriptions d'une équipe pour une saison, avec leur phase.
  Future<List<Engagement>> engagementsDetailles({
    required String equipeId,
    required String saisonId,
  }) async {
    final lignes = await _db
        .from('engagements')
        .select('id, equipe_id, saison_id, phase, competitions(id, nom, type)')
        .eq('equipe_id', equipeId)
        .eq('saison_id', saisonId);

    final liste = lignes.map((l) => Engagement.depuisJson(l)).toList();
    const rang = {'championnat': 0, 'coupe': 1, 'amical': 2};
    liste.sort((a, b) {
      final parType = (rang[a.competition.type] ?? 9).compareTo(
        rang[b.competition.type] ?? 9,
      );
      if (parType != 0) return parType;
      final parPhase = a.phase.compareTo(b.phase);
      return parPhase != 0
          ? parPhase
          : a.competition.nom.compareTo(b.competition.nom);
    });
    return liste;
  }

  Future<void> ajouterEngagement({
    required String equipeId,
    required String competitionId,
    required String saisonId,
    required int phase,
  }) async {
    await _db.from('engagements').insert({
      'equipe_id': equipeId,
      'competition_id': competitionId,
      'saison_id': saisonId,
      'phase': phase,
    });
  }

  /// Retire une inscription.
  ///
  /// Les rencontres déjà saisies dans cette compétition ne partent pas
  /// avec — elles ne référencent pas l'engagement mais la compétition.
  /// Elles resteront donc visibles : c'est voulu, un match joué a eu
  /// lieu, qu'on se soit trompé d'inscription ou non.
  Future<void> supprimerEngagement(String id) async {
    await _db.from('engagements').delete().eq('id', id);
  }
}
