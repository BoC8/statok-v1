import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/categorie_utils.dart';

/// Accès aux rencontres : les matchs joués (`matchs`) et les matchs à venir
/// (`programmations`).
///
/// RÈGLE
///   Ce fichier est le **seul** endroit où l'on écrit des requêtes sur ces deux
///   tables pour l'affichage public. Les pages ne parlent plus à Supabase.
///
/// CONVENTION
///   Le paramètre `categorie` reçoit le **libellé d'interface**
///   (`'U16 - U17 - U18'`), tel qu'il sort de `SharedPreferences`. La
///   conversion vers la valeur stockée en base est faite ici, une fois.
///
///   `categorie` ou `saison` à `null` signifie « pas de filtre sur ce critère ».
///
/// FORMAT DE RETOUR
///   Des `Map<String, dynamic>` bruts, tels que renvoyés par Supabase. Les
///   convertir en modèles typés (`MatchModel`, `ActionModel`) est le chantier
///   suivant ; le faire ici plutôt que dans les pages est déjà l'essentiel.
class MatchRepository {
  MatchRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// Colonnes ramenées pour un match joué : tout le match, le nom de
  /// l'adversaire, et ses actions avec le nom du joueur concerné.
  static const String _selectionMatch =
      '*, adversaires(nom), actions(type, joueurs(nom))';

  static const String _selectionProgrammation = '*, adversaires(nom)';

  /// Les matchs joués d'une catégorie et d'une saison, du plus récent au plus
  /// ancien.
  Future<List<Map<String, dynamic>>> matchsJoues({
    String? categorie,
    String? saison,
  }) async {
    var q = _client.from('matchs').select(_selectionMatch);
    q = _appliquerContexte(q, categorie, saison);
    return await q.order('date', ascending: false);
  }

  /// Les matchs joués d'une équipe donnée, du plus récent au plus ancien.
  Future<List<Map<String, dynamic>>> matchsDeLEquipe(
    String equipe, {
    String? categorie,
    String? saison,
  }) async {
    var q = _client
        .from('matchs')
        .select(_selectionMatch)
        .eq('equipe', equipe);
    q = _appliquerContexte(q, categorie, saison);
    return await q.order('date', ascending: false);
  }

  /// Les matchs programmés d'une catégorie et d'une saison, toutes dates
  /// confondues (le calendrier affiche aussi les programmations passées).
  Future<List<Map<String, dynamic>>> programmations({
    String? categorie,
    String? saison,
  }) async {
    var q = _client
        .from('programmations')
        .select(_selectionProgrammation);
    q = _appliquerContexte(q, categorie, saison);
    return await q;
  }

  /// Les prochaines rencontres d'une équipe, à partir d'aujourd'hui.
  Future<List<Map<String, dynamic>>> prochainesProgrammations(
    String equipe, {
    String? categorie,
    String? saison,
    int limite = 10,
    DateTime? aPartirDe,
  }) async {
    final depuis = aPartirDe ?? DateTime.now();
    var q = _client
        .from('programmations')
        .select(_selectionProgrammation)
        .eq('equipe', equipe)
        .gte('date', depuis.toIso8601String());
    q = _appliquerContexte(q, categorie, saison);
    return await q.order('date', ascending: true).limit(limite);
  }

  /// Applique le filtre catégorie + saison côté serveur.
  ///
  /// C'est ce qui évite de rapatrier toute la table pour en jeter la majorité
  /// en Dart, comme le faisait le code avant le 23/08/2026.
  PostgrestFilterBuilder<T> _appliquerContexte<T>(
    PostgrestFilterBuilder<T> query,
    String? categorie,
    String? saison,
  ) {
    var q = query;
    final dbCategorie = categoriePourDb(categorie);
    if (dbCategorie != null) q = q.eq('categorie', dbCategorie);
    if (saison != null) q = q.eq('saison', saison);
    return q;
  }
}
